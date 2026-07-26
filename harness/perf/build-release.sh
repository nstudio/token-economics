#!/usr/bin/env bash
set -uo pipefail

# Rebuilds every main-run trial's final source tree (preserved as trials/<id>
# branches) in Release configuration and archives the .app under
# results/<id>/app-release/. Perf is measured on these, never on the Debug
# archives — Debug carries dev-only weight (Lynx DevTool attach, unoptimized
# code) that misrepresents shipping behavior.

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(dirname "$HARNESS_DIR")"
RESULTS_DIR="$ROOT_DIR/results"

die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "==> $*"; }

run_build() { # run_build <fw> <repo> <log> ; sets APP
  local fw="$1" repo="$2" log="$3"
  APP=""
  if [ "$fw" = ns ]; then
    ( cd "$repo" && ns build ios --release ) >"$log" 2>&1 || return 1
    APP="$(ls -d "$repo"/platforms/ios/build/Release-iphonesimulator/*.app 2>/dev/null | head -1)"
  else
    ( cd "$repo" && npm run build && xcodebuild -workspace ios/SparklingGo.xcworkspace -scheme SparklingGo \
        -configuration Release -destination 'generic/platform=iOS Simulator' build ) >"$log" 2>&1 || return 1
    local products
    products="$(cd "$repo" && xcodebuild -workspace ios/SparklingGo.xcworkspace -scheme SparklingGo \
        -configuration Release -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')"
    APP="$(ls -d "$products"/*.app 2>/dev/null | head -1)"
  fi
  [ -n "$APP" ] && [ -d "$APP" ]
}

build_one() { # build_one <trial-id> ; returns nonzero on failure (batch continues)
  local id="$1" repo fw
  case "$id" in
    main-ns-*)   repo="$ROOT_DIR/ns-benchmark";  fw=ns ;;
    main-lynx-*) repo="$ROOT_DIR/lynx-benchmark"; fw=lynx ;;
    *) note "$id: unknown trial id, skipping"; return 1 ;;
  esac
  local dest="$RESULTS_DIR/$id/app-release"
  if [ -d "$dest" ]; then note "$id: app-release exists, skipping"; return 0; fi

  note "$id: checkout trials/$id"
  git -C "$repo" checkout -f -q "trials/$id" || { note "$id: checkout FAILED"; return 1; }
  git -C "$repo" clean -fd -q

  if ! git -C "$repo" diff --quiet benchmark-baseline -- package.json; then
    note "$id: package.json changed vs baseline — npm install"
    ( cd "$repo" && npm install --no-audit --no-fund ) >/dev/null 2>&1 || { note "$id: npm install FAILED"; return 1; }
  fi

  note "$id: release build"
  local log="$RESULTS_DIR/$id/build-logs/release.log"
  if ! run_build "$fw" "$repo" "$log"; then
    # codesign's transient "internal error" clears on retry more often than not
    note "$id: build failed once — retrying"
    if ! run_build "$fw" "$repo" "$log"; then
      note "$id: release build FAILED after retry (see build-logs/release.log)"
      return 1
    fi
  fi
  mkdir -p "$dest"
  ditto "$APP" "$dest/$(basename "$APP")"
  note "$id: archived $(basename "$APP") ($(du -sh "$dest" | cut -f1))"
}

restore_repo() { # restore_repo <repo>
  git -C "$1" checkout -f -q "$(git -C "$1" rev-parse benchmark-baseline^{commit})" 2>/dev/null
  git -C "$1" clean -fd -q
}

TRIALS="${*:-main-ns-1 main-lynx-1 main-ns-2 main-lynx-2 main-ns-3 main-lynx-3 main-ns-4 main-lynx-4 main-ns-5 main-lynx-5}"
FAILED=""
for id in $TRIALS; do build_one "$id" || FAILED="$FAILED $id"; done
restore_repo "$ROOT_DIR/ns-benchmark"
restore_repo "$ROOT_DIR/lynx-benchmark"
if [ -n "$FAILED" ]; then note "done with FAILURES:$FAILED (repos restored)"; exit 1; fi
note "done — repos restored to benchmark-baseline"
