#!/usr/bin/env bash
set -uo pipefail

# Token-economics benchmark trial runner (see ../PLAN.md §4–5).
#
# Usage:
#   ./run-trial.sh <study> <framework> [trial-id]
#   ./run-trial.sh remediate <trial-id> "<observed failure text>"
#
#   ./run-trial.sh ns-vs-expo expo main-expo-1
#
# Studies and frameworks are declared as JSON in studies/ and frameworks/ — adding
# either is a new file, never an edit to this script. List them with:
#   node lib/registry.mjs list-studies ; node lib/registry.mjs list-frameworks
#
# Environment:
#   MODEL / MAX_TURNS    override the study's pinned values (never do this mid-study)
#   ALLOW_FROZEN=1       permit writing trials into a frozen (published) study
#   SKIP_BASELINE_CHECK  set to 1 to skip the pre-trial baseline build verification
#   ANTHROPIC_API_KEY    recommended for headless runs; Keychain OAuth may also work
#
# Each phase runs in a fresh headless Claude Code session with an isolated
# CLAUDE_CONFIG_DIR (no global CLAUDE.md, memory, or personal settings) and exactly
# one docs MCP loaded via --strict-mcp-config. The harness — not the agent — commits
# after each phase and archives prompts, headless summaries, transcripts, build logs,
# and diffs under <study results dir>/<trial-id>/.

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$HARNESS_DIR")"
REGISTRY="$HARNESS_DIR/lib/registry.mjs"
source "$HARNESS_DIR/lib/common.sh"

die() { te_die "$@"; }
note() { te_note "$@"; }

load_context() { # load_context <study> <framework>
  local sh
  sh="$(node "$REGISTRY" sh "$1" "$2")" || exit 1
  eval "$sh"
  MODEL="${MODEL:-$STUDY_MODEL}"
  MAX_TURNS="${MAX_TURNS:-$STUDY_MAX_TURNS}"
}

manifest_set() { # manifest_set <dot.path> <json-value>
  node -e '
    const fs = require("fs");
    const [file, keypath, json] = process.argv.slice(1);
    const m = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {};
    const keys = keypath.split(".").filter(Boolean);
    let o = m;
    while (keys.length > 1) { const k = keys.shift(); o[k] = o[k] || {}; o = o[k]; }
    o[keys[0]] = JSON.parse(json);
    fs.writeFileSync(file, JSON.stringify(m, null, 2));
  ' "$MANIFEST" "$1" "$2"
}

render_prompt() { # render_prompt <template> <out> ; uses FRAMEWORK_LABEL, DOCS_MCP_NAME, BUILD_GATE, FAILURES env
  node -e '
    const fs = require("fs");
    const [tpl, out] = process.argv.slice(1);
    let t = fs.readFileSync(tpl, "utf8");
    for (const k of ["FRAMEWORK_LABEL", "DOCS_MCP_NAME", "BUILD_GATE", "FAILURES"])
      t = t.replaceAll("{{" + k + "}}", process.env[k] || "");
    fs.writeFileSync(out, t);
  ' "$1" "$2"
}

json_field() { # json_field <file> <field>
  node -e '
    try {
      const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      const v = process.argv[2].split(".").reduce((o, k) => (o || {})[k], j);
      if (v !== undefined && v !== null) process.stdout.write(String(v));
    } catch (e) {}
  ' "$1" "$2"
}

run_build_gate() { # run_build_gate <log-file> ; returns build exit status
  local log="$1"
  note "build gate: $BUILD_GATE"
  ( cd "$REPO" && bash -c "$BUILD_GATE" ) >"$log" 2>&1
}

archive_transcript() { # archive_transcript <summary-json> <dest-jsonl>
  local sid
  sid="$(json_field "$1" session_id)"
  [ -z "$sid" ] && { note "no session_id in $(basename "$1") — transcript not archived"; return 1; }
  local t
  t="$(find "$SCRATCH_CONFIG/projects" -name "$sid.jsonl" 2>/dev/null | head -1)"
  [ -z "$t" ] && t="$(find "$HOME/.claude/projects" -name "$sid.jsonl" 2>/dev/null | head -1)"
  [ -z "$t" ] && { note "transcript for session $sid not found"; return 1; }
  cp "$t" "$2"
}

run_session() { # run_session <prompt-file> <summary-out>
  ( cd "$REPO" && CLAUDE_CONFIG_DIR="$SCRATCH_CONFIG" claude -p "$(cat "$1")" \
      --output-format json \
      --model "$MODEL" \
      --max-turns "$MAX_TURNS" \
      --mcp-config "$MCP_CONFIG" \
      --strict-mcp-config \
      --dangerously-skip-permissions ) >"$2" 2>"$2.stderr"
}

run_phase() { # run_phase <label> <prompt-template>
  local label="$1" template="$2"
  local prompt="$TRIAL_DIR/phase-$label.prompt.md"
  local summary="$TRIAL_DIR/phase-$label.summary.json"
  local prev_sha
  prev_sha="$(git -C "$REPO" rev-parse HEAD)"

  render_prompt "$template" "$prompt"
  note "phase $label: starting session (model=$MODEL, max-turns=$MAX_TURNS)"
  local t0 t1
  t0="$(date +%s)"
  run_session "$prompt" "$summary"
  local rc=$?
  t1="$(date +%s)"

  archive_transcript "$summary" "$TRIAL_DIR/phase-$label.jsonl" || true

  run_build_gate "$TRIAL_DIR/build-logs/phase-$label.log"
  local build_rc=$?

  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "phase-$label" --no-verify || note "phase $label: nothing to commit"
  git -C "$REPO" diff --numstat "$prev_sha" HEAD >"$TRIAL_DIR/diffs/phase-$label.numstat"
  git -C "$REPO" diff "$prev_sha" HEAD >"$TRIAL_DIR/diffs/phase-$label.patch"

  manifest_set "phases.$label" "$(node -e '
    const fs = require("fs");
    const [summary, rc, buildRc, wall, sha] = process.argv.slice(1);
    let s = {};
    try { s = JSON.parse(fs.readFileSync(summary, "utf8")); } catch (e) {}
    console.log(JSON.stringify({
      session_id: s.session_id ?? null,
      exit_code: Number(rc),
      is_error: s.is_error ?? null,
      num_turns: s.num_turns ?? null,
      duration_ms: s.duration_ms ?? null,
      total_cost_usd: s.total_cost_usd ?? null,
      usage: s.usage ?? null,
      build_pass: Number(buildRc) === 0,
      wall_seconds: Number(wall),
      end_sha: sha
    }));
  ' "$summary" "$rc" "$build_rc" "$((t1 - t0))" "$(git -C "$REPO" rev-parse HEAD)")"

  if [ "$build_rc" -ne 0 ]; then
    note "phase $label: BUILD GATE FAILED (see build-logs/phase-$label.log) — trial stops here"
    manifest_set "outcome" '"failed-build-gate"'
    return 1
  fi
  note "phase $label: complete (build green, ${MAX_TURNS} turn cap, wall $((t1 - t0))s)"
}

archive_app() {
  # Preserve the built simulator .app so acceptance can run via `simctl install`
  # even after a later trial resets the repo.
  local dest="$TRIAL_DIR/app" app
  if app="$(te_locate_app "$FRAMEWORK" "$REPO" debug)"; then
    mkdir -p "$dest"
    ditto "$app" "$dest/$(basename "$app")"
    note "archived app: $STUDY_SLUG/$TRIAL_ID/app/$(basename "$app")"
  else
    note "WARNING: built .app not found — acceptance must run from the current repo state"
  fi
}

record_toolchain() {
  manifest_set "toolchain" "$(node -e '
    const cp = require("child_process");
    const sh = c => { try { return cp.execSync(c, {encoding: "utf8", stdio: ["ignore","pipe","ignore"]}).trim(); } catch (e) { return null; } };
    console.log(JSON.stringify({
      claude_version: sh("claude --version"),
      xcode: sh("xcodebuild -version | head -1"),
      macos: sh("sw_vers -productVersion"),
      node: sh("node -v"),
      docs_mcp: process.env.DOCS_MCP_VERSION || null
    }));
  ')"
}

preflight() {
  note "preflight: verifying headless auth in isolated config dir"
  local pf="$TRIAL_DIR/preflight.json"
  ( cd "$REPO" && CLAUDE_CONFIG_DIR="$SCRATCH_CONFIG" claude -p "Reply with exactly: ok" \
      --output-format json --model "$MODEL" --max-turns 1 \
      --strict-mcp-config --dangerously-skip-permissions ) >"$pf" 2>"$pf.stderr"
  local result
  result="$(json_field "$pf" result)"
  case "$result" in
    *ok*) note "preflight ok" ;;
    *) die "preflight failed — headless session did not respond (check $pf.stderr; fallback: run 'claude setup-token' once and export CLAUDE_CODE_OAUTH_TOKEN, or export ANTHROPIC_API_KEY)" ;;
  esac
}

preflight_mcp() {
  # An MCP server the agent cannot actually reach silently changes what is being
  # measured (docs friction collapses to zero). Verify the server loads before
  # spending a measured session on it.
  note "preflight: verifying docs MCP '$DOCS_MCP_NAME' loads"
  local pf="$TRIAL_DIR/preflight-mcp.json"
  ( cd "$REPO" && CLAUDE_CONFIG_DIR="$SCRATCH_CONFIG" claude -p "List the MCP tools or resources you can access. Reply with their names only." \
      --output-format json --model "$MODEL" --max-turns 2 \
      --mcp-config "$MCP_CONFIG" --strict-mcp-config \
      --dangerously-skip-permissions ) >"$pf" 2>"$pf.stderr"
  manifest_set "mcp_preflight" "$(node -e '
    const fs = require("fs");
    let s = {};
    try { s = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) {}
    console.log(JSON.stringify({ result: s.result ?? null, is_error: s.is_error ?? null }));
  ' "$pf")"
  note "preflight mcp: recorded (review manifest.mcp_preflight if docs counts look wrong)"
}

make_scratch_config() {
  # Throwaway config dir OUTSIDE results/ — it briefly holds a credentials copy,
  # which must never land in a directory that might get committed.
  SCRATCH_CONFIG="$(mktemp -d "${TMPDIR:-/tmp}/te-claude-cfg.XXXXXX")"
  trap 'rm -rf "$SCRATCH_CONFIG"' EXIT
  node -e '
    const fs = require("fs"), os = require("os"), path = require("path");
    const seed = { hasCompletedOnboarding: true };
    try {
      const src = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".claude.json"), "utf8"));
      for (const k of ["oauthAccount", "userID", "mcpOAuth"]) if (src[k] !== undefined) seed[k] = src[k];
    } catch (e) {}
    fs.writeFileSync(path.join(process.argv[1], ".claude.json"), JSON.stringify(seed));
  ' "$SCRATCH_CONFIG"
  AUTH_MODE="none-found"
  if [ -n "${ANTHROPIC_API_KEY:-}${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    AUTH_MODE="env-token"
  elif security find-generic-password -s "Claude Code-credentials" -w >"$SCRATCH_CONFIG/.credentials.json" 2>/dev/null; then
    chmod 600 "$SCRATCH_CONFIG/.credentials.json"
    AUTH_MODE="subscription-keychain"
  elif [ -f "$HOME/.claude/.credentials.json" ]; then
    rm -f "$SCRATCH_CONFIG/.credentials.json"
    cp "$HOME/.claude/.credentials.json" "$SCRATCH_CONFIG/.credentials.json"
    chmod 600 "$SCRATCH_CONFIG/.credentials.json"
    AUTH_MODE="subscription-file"
  else
    rm -f "$SCRATCH_CONFIG/.credentials.json"
  fi
}

reset_repo() {
  note "resetting $REPO to $BASELINE_TAG (hard reset + clean of untracked non-ignored files)"
  git -C "$REPO" rev-parse -q --verify "refs/tags/$BASELINE_TAG" >/dev/null || die "tag $BASELINE_TAG not found in $REPO"
  git -C "$REPO" reset --hard "$BASELINE_TAG" -q
  git -C "$REPO" clean -fd -q
}

# ---------------------------------------------------------------- remediate mode
if [ "${1:-}" = "remediate" ]; then
  TRIAL_ID="${2:-}"; FAILURES_TEXT="${3:-}"
  [ -n "$TRIAL_ID" ] && [ -n "$FAILURES_TEXT" ] || die "usage: ./run-trial.sh remediate <trial-id> \"<failures>\""
  MANIFEST="$(find "$ROOT_DIR/results" -maxdepth 3 -type d -name "$TRIAL_ID" -exec test -f '{}/manifest.json' \; -print -quit)/manifest.json"
  [ -f "$MANIFEST" ] || die "no manifest found for trial '$TRIAL_ID' under results/"
  TRIAL_DIR="$(dirname "$MANIFEST")"
  [ -n "$(json_field "$MANIFEST" phases.R.session_id)" ] && die "trial $TRIAL_ID already had its one remediation round"
  # Trials predating the study registry have no `study` field; their directory
  # placement under results/<slug>/ is the authority in that case.
  TRIAL_STUDY="$(json_field "$MANIFEST" study)"
  [ -z "$TRIAL_STUDY" ] && TRIAL_STUDY="$(basename "$(dirname "$TRIAL_DIR")")"
  load_context "$TRIAL_STUDY" "$(json_field "$MANIFEST" framework)"
  make_scratch_config
  export FAILURES="$FAILURES_TEXT"
  manifest_set "remediation_failures" "$(node -e 'console.log(JSON.stringify(process.env.FAILURES))')"
  run_phase "R" "$REMEDIATION_PROMPT"
  rm -rf "$TRIAL_DIR/app"
  archive_app
  note "remediation done — re-run the acceptance checklist and record results in manifest.json (acceptance)"
  exit 0
fi

# ---------------------------------------------------------------- trial mode
STUDY="${1:-}"; FRAMEWORK_ARG="${2:-}"
[ -n "$STUDY" ] && [ -n "$FRAMEWORK_ARG" ] || die "usage: ./run-trial.sh <study> <framework> [trial-id]
  studies:    $(node "$REGISTRY" list-studies | tr '\n' ' ')
  frameworks: $(node "$REGISTRY" list-frameworks | tr '\n' ' ')"

load_context "$STUDY" "$FRAMEWORK_ARG"

if [ "$STUDY_FROZEN" = "1" ] && [ "${ALLOW_FROZEN:-0}" != "1" ]; then
  die "study '$STUDY_SLUG' is frozen — $STUDY_FROZEN_REASON
  To reproduce it independently, set ALLOW_FROZEN=1 and use a trial id that cannot
  collide with the published set (e.g. repro-$FRAMEWORK-1)."
fi

TRIAL_ID="${3:-$FRAMEWORK-$(date +%Y%m%d-%H%M%S)}"
TRIAL_DIR="$RESULTS_DIR/$TRIAL_ID"
[ -e "$TRIAL_DIR" ] && die "$STUDY_SLUG/$TRIAL_ID already exists"
mkdir -p "$TRIAL_DIR"/{build-logs,diffs}
MANIFEST="$TRIAL_DIR/manifest.json"
make_scratch_config

note "trial $TRIAL_ID — $STUDY_TITLE / $FRAMEWORK_LABEL (spec $SPEC_VERSION, auth: $AUTH_MODE)"
manifest_set "auth_mode" "\"$AUTH_MODE\""
manifest_set "trial_id" "\"$TRIAL_ID\""
manifest_set "study" "\"$STUDY_SLUG\""
manifest_set "spec_version" "\"$SPEC_VERSION\""
manifest_set "framework" "\"$FRAMEWORK\""
manifest_set "model" "\"$MODEL\""
manifest_set "max_turns" "$MAX_TURNS"
manifest_set "mcp_config" "$(cat "$MCP_CONFIG")"
manifest_set "started_at" "\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
manifest_set "outcome" '"in-progress"'
manifest_set "acceptance" '{"status": "pending", "items": {}, "notes": ""}'
record_toolchain

reset_repo
manifest_set "baseline_sha" "\"$(git -C "$REPO" rev-parse HEAD)\""

if [ "${SKIP_BASELINE_CHECK:-0}" != "1" ]; then
  note "verifying baseline builds green (SKIP_BASELINE_CHECK=1 to skip)"
  run_build_gate "$TRIAL_DIR/build-logs/baseline.log" || die "baseline build failed — fix the baseline before measuring (see build-logs/baseline.log)"
fi

preflight
preflight_mcp

for n in $PHASE_IDS; do
  prompt_var="PHASE_PROMPT_$n"
  run_phase "$n" "${!prompt_var}" || exit 1
done

archive_app
manifest_set "outcome" '"phases-complete"'
manifest_set "finished_at" "\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
note "all phases green. Now run the app and execute SPEC.md §6 acceptance;"
note "record pass/fail per item in $MANIFEST under \"acceptance\", then set outcome to \"accepted\" or run:"
note "  ./run-trial.sh remediate $TRIAL_ID \"<observed failures>\"   (one round max, tokens counted)"
