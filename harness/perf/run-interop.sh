#!/usr/bin/env bash
set -uo pipefail

# JS↔native interop microbenchmarks (see PLAN.md §8). Hand-written bench apps
# live on the `interop-bench` branch of each framework repo: identical
# scenario code and an equivalent native fixture on both sides; the apps
# self-time each scenario and render INTEROPJSON:{...}, which the
# InteropCaptureTests driver collects. RUNS runs per framework (default 3).
#
# Env: SIM_UDID (required), RUNS (default 3), SKIP_BUILD=1 to reuse the
# already-built/installed apps.

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(dirname "$HARNESS_DIR")"
source "$HARNESS_DIR/lib/common.sh"
te_resolve_study "${STUDY:-}"
OUT_DIR="$PERF_DIR/interop"
DRIVER="$HARNESS_DIR/perf/uidriver"
RUNS="${RUNS:-3}"
SIM_UDID="${SIM_UDID:?set SIM_UDID (use a long-lived simulator)}"

die() { te_die "$@"; }
note() { te_note "$@"; }
mkdir -p "$OUT_DIR"

build_and_install() { # build_and_install <fw>
  local fw="$1" repo app branch gate
  repo="$(te_repo "$fw")"
  branch="$(node "$TE_REGISTRY" get "$fw" interopBranch)"
  gate="$(node "$TE_REGISTRY" get "$fw" releaseBuildGate)"
  note "$fw: checkout $branch + release build"
  git -C "$repo" checkout -q -f "$branch" || die "$fw: no $branch branch"
  ( cd "$repo" && bash -c "$gate" ) >"$OUT_DIR/$fw-build.log" 2>&1 || die "$fw: build failed"
  app="$(te_locate_app "$fw" "$repo" release)" || die "$fw: release .app not found"
  local bid
  bid="$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")"
  xcrun simctl uninstall "$SIM_UDID" "$bid" >/dev/null 2>&1
  xcrun simctl install "$SIM_UDID" "$app" || die "$fw: install failed"
}

capture_one() { # capture_one <fw> <run-n>
  local fw="$1" n="$2" bid
  bid="$(node "$TE_REGISTRY" get "$fw" bundleId)"
  local log="$OUT_DIR/.capture.$$"
  ( cd "$DRIVER" && TEST_RUNNER_TARGET_BUNDLE_ID="$bid" TEST_RUNNER_INTEROP_TIMEOUT=300 \
      xcodebuild test -project UIDriver.xcodeproj -scheme UIDriver -destination "id=$SIM_UDID" \
      -only-testing:UIDriverUITests/InteropCaptureTests ) >"$log" 2>&1
  local json
  json="$(grep -o 'INTEROPJSON:.*' "$log" | tail -1 | cut -c13-)"
  rm -f "$log"
  [ -n "$json" ] || { note "$fw run $n: NO RESULT"; return 1; }
  printf '%s\n' "$json" >"$OUT_DIR/$fw-run$n.json"
  note "$fw run $n: captured"
}

for fw in $STUDY_FRAMEWORKS; do
  [ "${SKIP_BUILD:-0}" = "1" ] || build_and_install "$fw"
done
# interleave runs so ambient host load spreads across every framework
for n in $(seq 1 "$RUNS"); do
  for fw in $STUDY_FRAMEWORKS; do
    capture_one "$fw" "$n" || true
  done
done
# leave repos back on the baseline commit
for fw in $STUDY_FRAMEWORKS; do
  repo="$(te_repo "$fw")"
  git -C "$repo" checkout -q -f "$(git -C "$repo" rev-parse "$BASELINE_TAG^{commit}")" 2>/dev/null
  git -C "$repo" clean -fd -q
done
note "done — analyze with: node analyze-interop.mjs $STUDY_SLUG"
