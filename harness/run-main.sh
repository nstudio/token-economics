#!/usr/bin/env bash
set -uo pipefail

# Main measurement run (PLAN §4.4): N interleaved trial pairs, sequential.
# Usage: ./run-main.sh [pairs]   (default 5 → main-ns-1..5 + main-lynx-1..5)
# A trial that fails its build gate is recorded and the batch continues.
# Already-existing trial dirs are skipped, so the batch is resumable.

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$(dirname "$HARNESS_DIR")/results"
PAIRS="${1:-5}"

for i in $(seq 1 "$PAIRS"); do
  for fw in ns lynx; do
    id="main-$fw-$i"
    if [ -e "$RESULTS_DIR/$id" ]; then
      echo "==> skipping $id (results/$id exists)"
      continue
    fi
    echo "==> starting trial $id"
    "$HARNESS_DIR/run-trial.sh" "$fw" "$id" || echo "==> trial $id FAILED (recorded in results/$id) — continuing batch"
  done
done
echo "==> batch done. Run acceptance per trial (apps archived under results/<id>/app), then: node analyze.mjs"
