#!/usr/bin/env bash
set -uo pipefail

# Measures shipping-representative app size: an unsigned arm64 device archive per
# trial, written to <study results>/perf/device/<trial>.json.
#
# The Release-simulator .app that build-release.sh produces is not an app-size
# proxy — it carries an x86_64 slice that never ships and full symbol tables, which
# together roughly double NativeScript and inflate Expo by about a third. Since the
# two arms are inflated by different amounts, the simulator ratio is wrong too, not
# just the absolute numbers. `archive` (not `build`) is what runs the strip and
# postprocessing an App Store build gets; signing is disabled because size does not
# depend on it. Still uncompressed and un-thinned, so these remain upper bounds on
# download size.
#
# Usage: STUDY=<slug> ./build-device.sh [trial-id ...]
# Env:   KEEP_ARCHIVES=1 to retain the .xcarchive bundles (large).

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(dirname "$HARNESS_DIR")"
source "$HARNESS_DIR/lib/common.sh"
te_resolve_study "${STUDY:-}"

die() { te_die "$@"; }
note() { te_note "$@"; }

DEVICE_DIR="$PERF_DIR/device"
mkdir -p "$DEVICE_DIR"

framework_of_trial() { # framework_of_trial <trial-id>
  local id="$1"
  for fw in $STUDY_FRAMEWORKS; do
    case "$id" in *-"$fw"-*) echo "$fw"; return 0 ;; esac
  done
  return 1
}

measure_app() { # measure_app <app> <out-json> <trial> <fw>
  node -e '
    const { execSync } = require("child_process"), fs = require("fs");
    const [app, out, trial, fw] = process.argv.slice(1);
    const du = p => Number(execSync(`du -sk "${p}"`).toString().split("\t")[0]) * 1024;
    const plist = k => execSync(`plutil -extract ${k} raw "${app}/Info.plist"`).toString().trim();
    const exe = `${app}/${plist("CFBundleExecutable")}`;
    const archs = execSync(`lipo -archs "${exe}"`).toString().trim().split(/\s+/);
    // A stripped binary keeps only a handful of entries; tens of thousands means
    // the strip phase did not run and the number is not comparable.
    const symbols = Number(execSync(`nm -a "${exe}" 2>/dev/null | wc -l`).toString().trim());
    const frameworks = {};
    const fwDir = `${app}/Frameworks`;
    if (fs.existsSync(fwDir)) for (const f of fs.readdirSync(fwDir)) frameworks[f] = du(`${fwDir}/${f}`);
    fs.writeFileSync(out, JSON.stringify({
      trial, framework: fw, configuration: "Release", destination: "generic/platform=iOS",
      signed: false, from: "xcarchive",
      bundle_bytes: du(app), executable_bytes: du(exe), archs, symbols, frameworks,
    }, null, 2) + "\n");
    const mb = b => (b / 1048576).toFixed(1);
    console.log(`    ${mb(du(app))} MB total · exe ${mb(du(exe))} MB · ${archs.join("+")} · ${symbols} symbols`);
  ' "$1" "$2" "$3" "$4"
}

build_one() { # build_one <trial-id>
  local id="$1" repo fw out
  fw="$(framework_of_trial "$id")" || { note "$id: no framework in $STUDY_SLUG matches, skipping"; return 1; }
  repo="$(te_repo "$fw")"
  out="$DEVICE_DIR/$id.json"
  if [ -f "$out" ]; then note "$id: already measured, skipping"; return 0; fi

  # Branch resolution is explicit on purpose. Trial ids repeat across studies, and
  # the pre-scoped naming (trials/<id>) was later reused by newer runs, so guessing
  # a flat name can silently measure another study's tree. Only a manifest entry,
  # a study-scoped branch, or an explicit legacyTrialBranches mapping is trusted.
  local br
  br="$(node -e 'try{console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).trial_branch||"")}catch(e){}' "$RESULTS_DIR/$id/manifest.json")"
  if [ -z "$br" ] && git -C "$repo" rev-parse --verify -q "trials/$STUDY_SLUG/$id" >/dev/null; then
    br="trials/$STUDY_SLUG/$id"
  fi
  if [ -z "$br" ]; then
    br="$(node -e '
      const s = require(process.argv[1]);
      process.stdout.write((s.legacyTrialBranches ?? {})[process.argv[2]] ?? "");
    ' "$HARNESS_DIR/studies/$STUDY_SLUG.json" "$id")"
  fi
  if [ -z "$br" ]; then
    note "$id: no known branch — source tree unavailable, skipping"
    return 1
  fi

  note "$id: checkout $br"
  git -C "$repo" checkout -f -q "$br" || { note "$id: checkout FAILED"; return 1; }
  git -C "$repo" clean -fdq -e node_modules -e platforms

  # Unconditional, not gated on package.json differing from baseline: node_modules
  # survives the checkout (it is excluded from the clean), so whatever the previous
  # trial left behind is what the build tool resolves against. A trial whose deps
  # were never installed otherwise fails in the bundler, not the compiler.
  ( cd "$repo" && npm install --no-audit --no-fund ) >/dev/null 2>&1 \
    || { note "$id: npm install FAILED"; return 1; }

  # Per-trial DerivedData. A shared one carries the previous trial's archive
  # intermediates, and xcodebuild fails to clear them ("couldn't be removed …
  # Operation not permitted") on projects with many Pod targets.
  export TE_ARCHIVE="$DEVICE_DIR/.archive-$id.xcarchive"
  export TE_DERIVED="$DEVICE_DIR/.dd-$id"
  rm -rf "$TE_ARCHIVE" "$TE_DERIVED"
  local gate log
  gate="$(node "$TE_REGISTRY" get "$fw" deviceBuildGate)" || return 1
  log="$RESULTS_DIR/$id/build-logs/device.log"
  mkdir -p "$(dirname "$log")"
  note "$id: device archive"
  if ! ( cd "$repo" && bash -c "$gate" ) >"$log" 2>&1; then
    note "$id: device archive FAILED (see build-logs/device.log)"
    rm -rf "$TE_ARCHIVE"; return 1
  fi

  # Raw xcodebuild output runs ~150 KB per trial and far more on the Pod-heavy
  # arms, so the archived log is compressed rather than dropped.
  gzip -f "$log"

  local app
  app="$(te_locate_app "$fw" "$repo" device)" || { note "$id: no .app in archive"; rm -rf "$TE_ARCHIVE"; return 1; }
  measure_app "$app" "$out" "$id" "$fw"
  rm -rf "$TE_DERIVED"
  [ "${KEEP_ARCHIVES:-0}" = "1" ] || rm -rf "$TE_ARCHIVE"
}

restore_repo() {
  git -C "$1" checkout -f -q "$(git -C "$1" rev-parse "$BASELINE_TAG^{commit}")" 2>/dev/null
  git -C "$1" clean -fdq -e node_modules -e platforms
}

default_trials() {
  local n fw rounds
  rounds="$(ls -d "$RESULTS_DIR"/main-*/ 2>/dev/null \
    | sed -nE 's|.*/main-[a-z]+-([0-9]+)/$|\1|p' | sort -n -u)"
  for n in $rounds; do
    for fw in $STUDY_FRAMEWORKS; do
      [ -d "$RESULTS_DIR/main-$fw-$n" ] && [ ! -f "$DEVICE_DIR/main-$fw-$n.json" ] && echo "main-$fw-$n"
    done
  done
}

TRIALS="${*:-$(default_trials | tr '\n' ' ')}"
[ -n "${TRIALS// /}" ] || die "no main-* trials to measure under $RESULTS_DIR"
FAILED=""
for id in $TRIALS; do build_one "$id" || FAILED="$FAILED $id"; done
for fw in $STUDY_FRAMEWORKS; do restore_repo "$(te_repo "$fw")"; done
if [ -n "$FAILED" ]; then note "done with FAILURES:$FAILED (repos restored)"; exit 1; fi
note "done — repos restored to $BASELINE_TAG"
