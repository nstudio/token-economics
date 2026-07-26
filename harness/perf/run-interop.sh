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
OUT_DIR="$ROOT_DIR/results/perf/interop"
DRIVER="$HARNESS_DIR/perf/uidriver"
RUNS="${RUNS:-3}"
SIM_UDID="${SIM_UDID:?set SIM_UDID (use a long-lived simulator)}"

die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "==> $*"; }
mkdir -p "$OUT_DIR"

build_and_install() { # build_and_install <fw>
  local fw="$1" repo app=""
  case "$fw" in
    ns) repo="$ROOT_DIR/ns-benchmark" ;;
    lynx) repo="$ROOT_DIR/lynx-benchmark" ;;
  esac
  note "$fw: checkout interop-bench + release build"
  git -C "$repo" checkout -q -f interop-bench || die "$fw: no interop-bench branch"
  if [ "$fw" = ns ]; then
    ( cd "$repo" && ns build ios --release ) >"$OUT_DIR/$fw-build.log" 2>&1 || die "$fw: build failed"
    app="$(ls -d "$repo"/platforms/ios/build/Release-iphonesimulator/*.app | head -1)"
  else
    ( cd "$repo" && npm run build && xcodebuild -workspace ios/SparklingGo.xcworkspace -scheme SparklingGo \
        -configuration Release -destination 'generic/platform=iOS Simulator' build ) >"$OUT_DIR/$fw-build.log" 2>&1 \
      || die "$fw: build failed"
    local products
    products="$(cd "$repo" && xcodebuild -workspace ios/SparklingGo.xcworkspace -scheme SparklingGo \
        -configuration Release -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')"
    app="$(ls -d "$products"/*.app | head -1)"
  fi
  local bid
  bid="$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")"
  xcrun simctl uninstall "$SIM_UDID" "$bid" >/dev/null 2>&1
  xcrun simctl install "$SIM_UDID" "$app" || die "$fw: install failed"
}

capture_one() { # capture_one <fw> <run-n>
  local fw="$1" n="$2" bid
  case "$fw" in
    ns) bid="org.nativescript.nsbenchmark" ;;
    lynx) bid="io.nstudio.lynx" ;;
  esac
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

for fw in ns lynx; do
  [ "${SKIP_BUILD:-0}" = "1" ] || build_and_install "$fw"
done
# interleave runs so ambient host load spreads across both frameworks
for n in $(seq 1 "$RUNS"); do
  for fw in ns lynx; do
    capture_one "$fw" "$n" || true
  done
done
# leave repos back on the baseline commit
for repo in "$ROOT_DIR/ns-benchmark" "$ROOT_DIR/lynx-benchmark"; do
  git -C "$repo" checkout -q -f "$(git -C "$repo" rev-parse benchmark-baseline^{commit})" 2>/dev/null
  git -C "$repo" clean -fd -q
done
note "done — analyze with: node analyze-interop.mjs"
