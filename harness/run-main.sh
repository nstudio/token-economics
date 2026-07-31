#!/usr/bin/env bash
set -uo pipefail

# Main measurement run (PLAN §4.4): N interleaved trial rounds, sequential.
#
# Usage: ./run-main.sh <study> [rounds]     e.g. ./run-main.sh ns-vs-expo 5
#
# One round runs one trial per framework in the study's declared order, so trials
# stay interleaved (ns, expo, ns, expo, …) and time-of-day / API-drift effects
# spread evenly across arms. A trial that fails its build gate is recorded and the
# batch continues. Already-existing trial dirs are skipped, so the batch is resumable.

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="$HARNESS_DIR/lib/registry.mjs"

STUDY="${1:-}"
ROUNDS="${2:-5}"

if [ -z "$STUDY" ]; then
  echo "usage: ./run-main.sh <study> [rounds]" >&2
  echo "  studies: $(node "$REGISTRY" list-studies | tr '\n' ' ')" >&2
  exit 2
fi

eval "$(node "$REGISTRY" sh-study "$STUDY")" || exit 1

echo "==> $STUDY_TITLE — $ROUNDS rounds × [$STUDY_FRAMEWORKS], sequential and interleaved"

for i in $(seq 1 "$ROUNDS"); do
  for fw in $STUDY_FRAMEWORKS; do
    id="main-$fw-$i"
    if [ -e "$RESULTS_DIR/$id" ]; then
      echo "==> skipping $id ($STUDY_SLUG/$id exists)"
      continue
    fi
    echo "==> starting trial $id"
    "$HARNESS_DIR/run-trial.sh" "$STUDY" "$fw" "$id" \
      || echo "==> trial $id FAILED (recorded in $STUDY_SLUG/$id) — continuing batch"
  done
done
echo "==> batch done. Run acceptance per trial (apps archived under <trial>/app), then: node analyze.mjs $STUDY"
