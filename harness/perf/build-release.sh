#!/usr/bin/env bash
set -uo pipefail

# Rebuilds every main-run trial's final source tree (preserved as trials/<id>
# branches) in Release configuration and archives the .app under
# <study results>/<id>/app-release/. Perf is measured on these, never on the Debug
# archives — Debug carries dev-only weight (Lynx DevTool attach, unoptimized
# code) that misrepresents shipping behavior.
#
# Usage: STUDY=<slug> ./build-release.sh [trial-id ...]

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(dirname "$HARNESS_DIR")"
source "$HARNESS_DIR/lib/common.sh"
te_resolve_study "${STUDY:-}"

die() { te_die "$@"; }
note() { te_note "$@"; }

run_build() { # run_build <fw> <repo> <log> ; sets APP
  local fw="$1" repo="$2" log="$3" gate
  APP=""
  gate="$(node "$TE_REGISTRY" get "$fw" releaseBuildGate)" || return 1
  ( cd "$repo" && bash -c "$gate" ) >"$log" 2>&1 || return 1
  APP="$(te_locate_app "$fw" "$repo" release)" || return 1
  [ -n "$APP" ] && [ -d "$APP" ]
}

framework_of_trial() { # framework_of_trial <trial-id>
  local id="$1"
  for fw in $STUDY_FRAMEWORKS; do
    case "$id" in *-"$fw"-*) echo "$fw"; return 0 ;; esac
  done
  return 1
}

build_one() { # build_one <trial-id> ; returns nonzero on failure (batch continues)
  local id="$1" repo fw
  fw="$(framework_of_trial "$id")" || { note "$id: no framework in study $STUDY_SLUG matches, skipping"; return 1; }
  repo="$(te_repo "$fw")"
  local dest="$RESULTS_DIR/$id/app-release"
  if [ -d "$dest" ]; then note "$id: app-release exists, skipping"; return 0; fi

  # The manifest records the exact branch for this trial; trial ids repeat across
  # studies, so never reconstruct the name from the id alone.
  local br
  br="$(node -e 'try{console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).trial_branch||"")}catch(e){}' "$RESULTS_DIR/$id/manifest.json")"
  [ -n "$br" ] || br="trials/$STUDY_SLUG/$id"
  note "$id: checkout $br"
  git -C "$repo" checkout -f -q "$br" || { note "$id: checkout FAILED"; return 1; }
  git -C "$repo" clean -fd -q

  if ! git -C "$repo" diff --quiet "$BASELINE_TAG" -- package.json; then
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
  git -C "$1" checkout -f -q "$(git -C "$1" rev-parse "$BASELINE_TAG^{commit}")" 2>/dev/null
  git -C "$1" clean -fd -q
}

# Default: every main-* trial present in the study's results, interleaved by round
# so a partial batch still covers both arms evenly.
default_trials() {
  local n fw
  for n in 1 2 3 4 5; do
    for fw in $STUDY_FRAMEWORKS; do
      [ -d "$RESULTS_DIR/main-$fw-$n" ] && echo "main-$fw-$n"
    done
  done
}

TRIALS="${*:-$(default_trials | tr '\n' ' ')}"
[ -n "${TRIALS// /}" ] || die "no main-* trials found under $RESULTS_DIR"
FAILED=""
for id in $TRIALS; do build_one "$id" || FAILED="$FAILED $id"; done
for fw in $STUDY_FRAMEWORKS; do restore_repo "$(te_repo "$fw")"; done
if [ -n "$FAILED" ]; then note "done with FAILURES:$FAILED (repos restored)"; exit 1; fi
note "done — repos restored to $BASELINE_TAG"
