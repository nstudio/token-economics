#!/usr/bin/env bash
set -uo pipefail

# Copies a study's SPEC.md + spec-assets/ into every framework repo in that study
# and verifies the copies are byte-identical. Spec parity is the load-bearing
# fairness claim of the whole benchmark, so it is enforced by a tool rather than
# by remembering to copy files.
#
# Usage: ./sync-spec.sh <study> [--check]
#   --check   verify only; exit nonzero on drift (use in CI / before tagging)

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HARNESS_DIR/lib/common.sh"

STUDY="${1:-}"
MODE="${2:-}"
te_resolve_study "$STUDY"

[ -d "$SPEC_DIR" ] || te_die "spec dir not found: $SPEC_DIR"

hash_tree() { # hash_tree <dir> — stable digest of SPEC.md + spec-assets
  ( cd "$1" && find SPEC.md spec-assets -type f 2>/dev/null | sort | xargs shasum -a 256 )
}

SRC_HASH="$(hash_tree "$SPEC_DIR")"
[ -n "$SRC_HASH" ] || te_die "no SPEC.md/spec-assets under $SPEC_DIR"

fail=0
for fw in $STUDY_FRAMEWORKS; do
  repo="$(te_repo "$fw")"
  if [ ! -d "$repo" ]; then
    te_note "$fw: repo missing at $repo — skipping"
    fail=1
    continue
  fi
  if [ "$MODE" != "--check" ]; then
    rm -rf "$repo/spec-assets"
    cp "$SPEC_DIR/SPEC.md" "$repo/SPEC.md"
    cp -R "$SPEC_DIR/spec-assets" "$repo/spec-assets"
  fi
  if [ "$(hash_tree "$repo")" = "$SRC_HASH" ]; then
    te_note "$fw: spec $SPEC_VERSION verified identical"
  else
    te_note "$fw: SPEC DRIFT vs $SPEC_VERSION"
    diff <(echo "$SRC_HASH") <(hash_tree "$repo") || true
    fail=1
  fi
done

[ "$fail" -eq 0 ] || te_die "spec parity check failed for study $STUDY_SLUG"
te_note "all repos in $STUDY_SLUG carry byte-identical spec $SPEC_VERSION"
