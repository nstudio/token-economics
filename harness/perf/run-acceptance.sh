#!/usr/bin/env bash
set -uo pipefail

# Automated functional acceptance over the archived Debug apps.
#
#   STUDY=<slug> SIM_UDID=<udid> ./run-acceptance.sh [trial-id ...]
#
# Runs the same XCUITest driver as the latency suite, but against each trial's
# archived Debug .app (<trial>/app/) rather than a Release rebuild — those are the
# exact binaries the agents produced, so nothing is re-derived between what was
# measured and what is checked.
#
# It answers the question the build gate cannot: does the app actually WORK?
# The driver taps SPEC-pinned labels, grants the permission sheets, and records
# whether each flow reached its observable result. Output per trial:
#   <study>/acceptance/<trial>.json
#
# This is deliberately the same driver the perf suite uses, so a trial cannot pass
# acceptance under one definition and fail under another.
#
# Do not run this while measured trials are in flight — XCUITest is CPU-heavy and
# would distort their recorded wall-clock.

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$HARNESS_DIR/lib/common.sh"
te_resolve_study "${STUDY:-}"

OUT_DIR="$RESULTS_DIR/acceptance"
DRIVER="$HARNESS_DIR/perf/uidriver"
ITERS="${ITERS:-1}"
SIM_UDID="${SIM_UDID:?set SIM_UDID (use a long-lived simulator; pristine ones lack speech services)}"

note() { te_note "$@"; }
mkdir -p "$OUT_DIR"

check_one() { # check_one <trial-id>
  local id="$1"
  local app bid
  app="$(ls -d "$RESULTS_DIR/$id/app"/*.app 2>/dev/null | head -1)"
  [ -n "$app" ] || { note "$id: no archived app, skipping"; return 1; }
  bid="$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")"

  # A clean install per trial: permission state is sticky, and a granted
  # leftover would make the deny paths untestable and the grant paths trivial.
  xcrun simctl uninstall "$SIM_UDID" "$bid" >/dev/null 2>&1
  xcrun simctl install "$SIM_UDID" "$app" || { note "$id: install FAILED"; return 1; }

  note "$id ($bid): driving SPEC flows"
  local log="$OUT_DIR/.run.$$"
  # xcodebuild strips the TEST_RUNNER_ prefix before the test process sees these.
  ( cd "$DRIVER" && TEST_RUNNER_TARGET_BUNDLE_ID="$bid" TEST_RUNNER_ITERS="$ITERS" \
      xcodebuild test -project UIDriver.xcodeproj -scheme UIDriver \
      -destination "id=$SIM_UDID" \
      -only-testing:UIDriverUITests/FeatureLatencyTests ) >"$log" 2>&1
  local json
  json="$(grep -o 'PERFJSON:.*' "$log" | tail -1 | cut -c10-)"
  rm -f "$log"
  if [ -z "$json" ]; then
    note "$id: driver produced no result (recorded as undetermined)"
    printf '{"trial":"%s","status":"undetermined"}\n' "$id" >"$OUT_DIR/$id.json"
    return 1
  fi
  printf '%s\n' "$json" >"$OUT_DIR/$id.json"
  note "$id: captured"
}

default_trials() {
  for d in "$RESULTS_DIR"/main-*/; do
    t="$(basename "$d")"
    case "$t" in *infra-invalid*) continue ;; esac
    [ -d "$d/app" ] && echo "$t"
  done
}

TRIALS="${*:-$(default_trials | tr '\n' ' ')}"
[ -n "${TRIALS// /}" ] || te_die "no trials with archived apps under $RESULTS_DIR"

for id in $TRIALS; do check_one "$id" || true; done
note "done — summarise with: node analyze-acceptance.mjs $STUDY_SLUG"
