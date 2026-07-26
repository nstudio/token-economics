# Benchmark harness

Runs the measurement protocol defined in `../PLAN.md`. One **trial** = 3 fresh headless Claude Code sessions (shell → Health → Transcribe) against a repo reset to the `benchmark-baseline` tag.

## Run a trial

```sh
# pilot
MODEL=claude-sonnet-5 ./run-trial.sh ns   pilot-ns-1
MODEL=claude-sonnet-5 ./run-trial.sh lynx pilot-lynx-1

# main runs: interleave ns / lynx, keep MODEL identical everywhere
```

Env knobs: `MODEL` (default `claude-sonnet-5`), `MAX_TURNS` (default 160/phase, calibrated by pilot), `SKIP_BASELINE_CHECK=1`.

Auth: your Claude **subscription works automatically** — the runner seeds a throwaway config dir (created via `mktemp`, deleted on exit, never under `results/`) with the account stub and a copy of the Keychain OAuth credential. `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`), if exported, take precedence. A preflight call verifies auth before any measured session. Under subscription auth, `total_cost_usd` is an estimated list-price figure, not a bill — token counts are exact either way; the manifest records `auth_mode`.

Subscription caveats: run measured trials **sequentially, never concurrently** (they share the plan's usage window, and CPU contention from parallel `xcodebuild` skews wall-clock). If a session dies on a usage limit mid-trial, mark that trial infra-invalid in its manifest (not a framework failure) and re-run it in a fresh usage window.

What the runner does per trial: reset repo to baseline → verify baseline builds → preflight → for each phase: render prompt, run headless session (`--strict-mcp-config` with that framework's docs MCP only, `--dangerously-skip-permissions`), archive transcript JSONL + headless summary, run the build gate, harness-commit `phase-N`, save diff/numstat. A failed build gate stops the trial and records `outcome: failed-build-gate`.

## After the phases

1. Launch the app on the iOS Simulator and run the SPEC.md §6 acceptance checklist.
2. Record results in `results/<trial-id>/manifest.json` under `acceptance` (set `status` to `pass`/`fail`, fill `items`), and set `outcome` to `accepted` — or run the single allowed remediation round (tokens counted):

```sh
./run-trial.sh remediate <trial-id> "Transcribe: partial results never stream; final appears all at once"
```

## Analyze

```sh
node analyze.mjs   # writes results/summary.csv + results/summary.json, prints tables
```

Per trial×phase: the four token buckets (from transcript JSONL, deduped per message id), cost, turns, wall time, tool mix (docs-MCP calls counted separately), LOC added split JS-side vs native-side. Aggregates: medians per framework×phase plus per-trial totals.

Don't compare trials run with different `MODEL` values — the model is pinned per PLAN §4.3.

## Performance suites (harness/perf/)

```sh
cd perf
./build-release.sh                                  # Release rebuilds of every trial (from trials/* branches)
SIM_UDID=<udid> ./measure.sh                        # size + cold launches + idle memory/CPU
SIM_UDID=<udid> ITERS=3 ./run-interactions.sh       # tap-to-result API latency (UI-test driver)
SIM_UDID=<udid> RUNS=3 ./run-interop.sh             # JS↔native interop microbenchmarks (interop-bench branches)
node analyze-perf.mjs && node analyze-interactions.mjs && node analyze-interop.mjs
```

Use a long-lived simulator (pristine ones lack speech services) and a quiet host. `run-interop.sh` checks out and restores the framework repos' `interop-bench` branches — the bench sources must be committed on those branches (the restore step discards uncommitted work).
