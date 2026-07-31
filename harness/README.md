# Benchmark harness

Runs the measurement protocol defined in `../PLAN.md`. One **trial** = 3 fresh headless Claude Code sessions (shell → Health → Transcribe) against a repo reset to that study's baseline tag.

The harness is **registry-driven**: frameworks and studies are JSON declarations, not code paths. Adding a framework or a comparison is a new file, never an edit to a runner.

```
harness/
  frameworks/<id>.json   one per framework: repo, build gates, app locators, docs MCP, LOC roots
  studies/<slug>.json    one per comparison: which frameworks, spec version, baseline tag,
                         results dir, pinned model/turn cap, trial-set patterns, frozen flag
  spec/v<X.Y>/           versioned SPEC.md + spec-assets (copied byte-identically into each repo)
  baselines/<fw>/        baseline docs for a framework's repo (CLAUDE.md)
  prompts/               phase templates — never edited between trials
  mcp/<fw>.mcp.json      one docs-MCP config per framework
  lib/registry.mjs       the registry + LOC classifier (shared by every runner and analyzer)
  lib/common.sh          shared shell helpers (study resolution, build-product location)
```

```sh
node lib/registry.mjs list-studies      # ns-vs-lynx  ns-vs-expo  ns-vs-expo-open
node lib/registry.mjs list-frameworks   # expo  lynx  ns
node lib/registry.mjs study ns-vs-expo  # the full resolved declaration
```

## Run a trial

```sh
./run-trial.sh <study> <framework> [trial-id]

./run-trial.sh ns-vs-expo ns   pilot-ns-1
./run-trial.sh ns-vs-expo expo pilot-expo-1

# full main run: N interleaved rounds across the study's frameworks, sequential, resumable
./run-main.sh ns-vs-expo 5
```

Env knobs: `MODEL` / `MAX_TURNS` (override the study's pinned values — don't, mid-study), `SKIP_BASELINE_CHECK=1`, `ALLOW_FROZEN=1`.

**Frozen studies.** A study with `"frozen": true` refuses new trials. `ns-vs-lynx` is frozen because it is published: appending trials to a released dataset would silently change numbers the site links to. To reproduce it independently, set `ALLOW_FROZEN=1` and use a non-colliding trial id (`repro-ns-1`).

Auth: your Claude **subscription works automatically** — the runner seeds a throwaway config dir (created via `mktemp`, deleted on exit, never under `results/`) with the account stub and a copy of the Keychain OAuth credential. `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`), if exported, take precedence. Two preflights run before any measured session: one verifies auth, one verifies the docs MCP actually loads — an unreachable MCP silently collapses docs friction to zero, which would corrupt the comparison rather than fail it.

Subscription caveats: run measured trials **sequentially, never concurrently** (they share the plan's usage window, and CPU contention from parallel `xcodebuild` skews wall-clock). If a session dies on a usage limit mid-trial, mark that trial infra-invalid in its manifest (not a framework failure) and re-run it in a fresh usage window. Under subscription auth, `total_cost_usd` is an estimated list-price figure, not a bill — token counts are exact either way; the manifest records `auth_mode`.

What the runner does per trial: reset repo to the study's baseline tag → verify baseline builds → preflight auth + MCP → for each phase: render prompt, run headless session (`--strict-mcp-config` with that framework's docs MCP only, `--dangerously-skip-permissions`), archive transcript JSONL + headless summary, run the build gate, harness-commit `phase-N`, save diff/numstat. A failed build gate stops the trial and records `outcome: failed-build-gate`.

## Spec parity

```sh
./sync-spec.sh ns-vs-expo            # copy the study's spec into every framework repo
./sync-spec.sh ns-vs-expo --check    # verify byte-identity; nonzero exit on drift
```

Run `--check` before tagging a baseline. Byte-identical specs across arms are the benchmark's load-bearing fairness claim, so it is enforced by a tool rather than by remembering.

## After the phases

1. Launch the app on the iOS Simulator and run the SPEC.md §6 acceptance checklist.
2. Record results in `<study results>/<trial-id>/manifest.json` under `acceptance` (set `status` to `pass`/`fail`, fill `items`), and set `outcome` to `accepted` — or run the single allowed remediation round (tokens counted):

```sh
./run-trial.sh remediate <trial-id> "Transcribe: partial results never stream; final appears all at once"
```

## Analyze

```sh
node analyze.mjs                 # every study
node analyze.mjs ns-vs-expo      # one study → <study>/summary.csv + summary.json
```

Per trial×phase: the four token buckets (from transcript JSONL, deduped per message id), cost, turns, wall time, tool mix (docs-MCP calls counted separately), the turn-1 fixed-context size (system prompt + CLAUDE.md + MCP tool schemas), and LOC added split three ways:

| Bucket | Contents |
|---|---|
| `loc_js_added` | app code — `.ts .tsx .js .jsx .vue .css` |
| `loc_native_code_added` | native-language source — `.swift .m .h .mm .kt .java` |
| `loc_native_config_added` | native project/permission config — plists, entitlements, xcconfig, podspecs, and a framework's declared config paths (e.g. Expo's `app.json`) |

`loc_native_added` remains the sum of the two native buckets, so the three-way split never moves previously published two-way numbers.

Aggregates are computed **per trial set** (`pilot`, `main`, …, matched by the study's `trialSets` patterns) and never pooled across sets — pilot runs used a different turn cap. The headline medians come from the study's `medianSet`.

Studies are analyzed independently and never pooled: a median is only meaningful within one spec version, one model, and one measurement window.

## Evidence manifest

```sh
node manifest.mjs ns-vs-lynx            # write <study>/MANIFEST.sha256
node manifest.mjs ns-vs-lynx --check    # verify; prints ADDED/CHANGED/REMOVED on drift
```

SHA-256 of every archived artifact (transcripts, manifests, diffs, build logs, prompts, perf JSON). Regenerable app binaries are excluded. `--check` is the audit trail behind every published number.

## Performance suites (harness/perf/)

```sh
cd perf
STUDY=ns-vs-expo ./build-release.sh                            # Release rebuilds from trials/* branches
STUDY=ns-vs-expo SIM_UDID=<udid> ./measure.sh                  # size + cold launches + idle memory/CPU
STUDY=ns-vs-expo SIM_UDID=<udid> ITERS=3 ./run-interactions.sh # tap-to-result API latency (UI-test driver)
STUDY=ns-vs-expo SIM_UDID=<udid> RUNS=3 ./run-interop.sh       # JS↔native interop microbenchmarks

node analyze-perf.mjs ns-vs-expo
node analyze-interactions.mjs ns-vs-expo
node analyze-interop.mjs ns-vs-expo
```

Use a long-lived simulator (pristine ones lack speech services) and a quiet host. `run-interop.sh` checks out and restores each framework repo's `interopBranch` — the bench sources must be committed on those branches (the restore step discards uncommitted work).

The interop analyzer treats the study's **first** framework as the ratio baseline, and flags any scenario whose `check` values disagree across arms — that check is the proof the workloads are identical.

## Adding a comparison

1. `frameworks/<id>.json` — repo dir, bundle id, Debug/Release build gates + app locators, docs MCP config, native path roots.
2. `mcp/<id>.mcp.json` — that framework's docs MCP.
3. `baselines/<id>/CLAUDE.md` — structurally identical to the existing ones: same sections, same level of help, no feature hints.
4. `spec/v<X.Y>/` — a new spec version if the rules changed; otherwise reuse one.
5. `studies/<slug>.json` — frameworks, spec dir, baseline tag, results dir, pinned model and turn cap.
6. `./sync-spec.sh <slug>`, verify every baseline builds green, tag them, then `./run-main.sh <slug> 5`.

Don't compare trials run with different `MODEL` values, different spec versions, or across studies — the model and spec are pinned per study by design.
