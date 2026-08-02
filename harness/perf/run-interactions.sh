#!/usr/bin/env bash
set -uo pipefail

# Feature-path latency measurement: drives each trial's Release app through the
# HealthKit and Speech flows with the generic XCUITest driver (uidriver/), which
# operates purely on SPEC.md's pinned labels — agent-built apps are never modified.
# Emits results/perf/interactions/<trial>.json from the driver's PERFJSON line.
#
# Env: SIM_UDID (required — use a long-lived simulator; pristine sims lack the
# speech-recognition services and the recognizer fails to initialize),
# ITERS (default 3).

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(dirname "$HARNESS_DIR")"
source "$HARNESS_DIR/lib/common.sh"
te_resolve_study "${STUDY:-}"
OUT_DIR="$PERF_DIR/interactions"
DRIVER="$HARNESS_DIR/perf/uidriver"
ITERS="${ITERS:-3}"
SIM_UDID="${SIM_UDID:?set SIM_UDID}"

note() { te_note "$@"; }
mkdir -p "$OUT_DIR"

measure_one() { # measure_one <trial-id>
  local id="$1"
  if [ -f "$OUT_DIR/$id.json" ]; then note "$id: exists, skipping"; return 0; fi
  local app bid
  app="$(ls -d "$RESULTS_DIR/$id/app-release"/*.app 2>/dev/null | head -1)"
  [ -n "$app" ] || { note "$id: no app-release, skipping"; return 1; }
  bid="$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")"
  note "$id ($bid): install + drive ($ITERS iterations)"
  xcrun simctl uninstall "$SIM_UDID" "$bid" >/dev/null 2>&1
  xcrun simctl install "$SIM_UDID" "$app" || { note "$id: install failed"; return 1; }

  local log="$OUT_DIR/$id.xcodebuild.log"
  ( cd "$DRIVER" && TEST_RUNNER_TARGET_BUNDLE_ID="$bid" TEST_RUNNER_ITERS="$ITERS" \
      xcodebuild test -project UIDriver.xcodeproj -scheme UIDriver -destination "id=$SIM_UDID" ) >"$log" 2>&1
  local json
  json="$(grep -o 'PERFJSON:.*' "$log" | tail -1 | cut -c10-)"
  if [ -z "$json" ]; then note "$id: NO PERFJSON (see $(basename "$log"))"; return 1; fi
  node -e '
    const fs = require("fs");
    const [out, id, json] = process.argv.slice(1);
    const d = JSON.parse(json);
    d.trial = id;
    d.measured_at = new Date().toISOString();
    fs.writeFileSync(out, JSON.stringify(d, null, 2));
  ' "$OUT_DIR/$id.json" "$id" "$json"
  note "$id: wrote interactions/$id.json"
  xcrun simctl terminate "$SIM_UDID" "$bid" >/dev/null 2>&1
}

# Discovered from the study's results, interleaved by round. Never hardcoded:
# v1.0's literal list silently omitted main-lynx-5, so that study measured 9 of
# 10 apps with nothing to indicate the gap.
default_trials() {
  local n fw rounds
  rounds="$(ls -d "$RESULTS_DIR"/main-*/ 2>/dev/null \
    | sed -nE 's|.*/main-[a-z]+-([0-9]+)/$|\1|p' | sort -n -u)"
  for n in $rounds; do
    for fw in $STUDY_FRAMEWORKS; do
      [ -d "$RESULTS_DIR/main-$fw-$n/app-release" ] && echo "main-$fw-$n"
    done
  done
}

TRIALS="${*:-$(default_trials | tr '\n' ' ')}"
[ -n "${TRIALS// /}" ] || te_die "no trials with Release apps under $RESULTS_DIR"
FAILED=""
for id in $TRIALS; do measure_one "$id" || FAILED="$FAILED $id"; done
[ -n "$FAILED" ] && note "completed with issues:$FAILED" || note "all interaction measurements complete"
