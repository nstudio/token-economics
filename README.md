# Token Economics — agent token cost of building the same app across mobile frameworks

How many tokens does an AI coding agent consume to build the **same iOS app** — same spec, same UI, two deep native-platform features (HealthKit + Speech) — in one framework versus another?

Each **study** pins a spec version, a model, and a pair of frameworks, then runs fresh, isolated, headless Claude Code sessions under a controlled protocol and measures what the architectural difference costs in agent tokens. The finished apps are then profiled at runtime, so build cost and product quality are reported together.

**Results site:** [agent-tokenomics](https://github.com/nstudio/agent-tokenomics) — interactive charts, methodology, and reproduction guide, generated from this repo's raw data.

## Studies

| Study | Spec | Status | Findings |
|---|---|---|---|
| `ns-vs-lynx` — NativeScript vs LynxJS (Sparkling) | v1.0.0 | **published, frozen** | [REPORT.md](results/ns-vs-lynx/REPORT.md) — 1.9× output tokens, 4.0× on the second native feature |
| `ns-vs-expo` — NativeScript vs Expo (React Native) | v1.1.0 | planned — see [`PLAN-EXPO.md`](PLAN-EXPO.md) | — |
| `ns-vs-expo-open` — same, wrapper-allowed condition | v1.1.0-open | planned (secondary) | — |

A published study is **frozen**: its numbers are never edited in place, and the harness refuses to append trials to it. A changed model, framework version, or spec is a new study slug.

## Layout

| Path | What |
|---|---|
| `PLAN.md` | **Methods** — full experimental design: definitions, protocol, controls, confounders |
| `PLAN-EXPO.md` | Methods delta for the NativeScript vs Expo study (spec v1.1) |
| `harness/` | Runner + analyzers, registry-driven — see [`harness/README.md`](harness/README.md) |
| `harness/frameworks/`, `harness/studies/` | The registry: one JSON per framework, one per study |
| `harness/spec/v<X.Y>/` | Versioned `SPEC.md` (the app spec every framework implements) + fixed assets |
| `apps/<fw>-benchmark/` | Each framework's baseline — the exact blank start state every trial reset to |
| `apps/trials/` | Every main-run trial's final source tree, exported (what each agent actually built) |
| `apps/interop-bench/` | Hand-written JS↔native interop microbenchmark apps (identical scenarios + equivalent native fixture per framework) |
| `results/<study>/<trial-id>/` | Per trial: manifest, full session transcripts (JSONL), diffs, build logs |
| `results/<study>/REPORT.md` | **Findings** — that study's write-up |
| `results/<study>/perf/` | Runtime measurements (size, launch, memory, API-path latency, interop) |
| `results/<study>/MANIFEST.sha256` | SHA-256 of every archived artifact — the audit trail behind every published number |

Note: trial `.app` binaries are not committed (~3 GB); rebuild any trial's app from its source in `apps/trials/` via `harness/perf/build-release.sh`.

## Reproduce

```sh
cd harness
node lib/registry.mjs list-studies                 # what's available

./run-trial.sh ns-vs-expo ns my-trial-1            # one trial (3 phased sessions + build gates)
./run-main.sh ns-vs-expo 5                         # full main run, interleaved and resumable
node analyze.mjs ns-vs-expo                        # summary.csv / summary.json + median tables
node manifest.mjs ns-vs-expo --check               # verify archived evidence is unchanged
```

To reproduce the published study rather than extend it: `ALLOW_FROZEN=1 ./run-trial.sh ns-vs-lynx ns repro-ns-1`.

Requirements: macOS with Xcode 26.5, Node 22+, Claude Code CLI, an iOS Simulator, and a Claude subscription or API key (auth is handled automatically — see `harness/README.md`).

> **Resuming after a pause / disk cleanup:** rebuildable artifacts — `node_modules/` in the working framework repos and `agent-tokenomics/`, `ns-benchmark/platforms/`, `lynx-benchmark/ios/build/`, and study-related Xcode DerivedData — may be deleted between work sessions to reclaim space. Run `npm ci` in each repo you touch before running trials, remediation rounds, or Release rebuilds. Do **not** delete `results/<study>/<trial-id>/app/` (pending operator acceptance installs exactly those archived binaries) or `.../app-release/` (the exact Release binaries the perf numbers were measured from) until that study closes.

## Key measurement principles

- Every session runs **fresh and isolated** (throwaway `CLAUDE_CONFIG_DIR`: no personal settings, memory, or global instructions) with exactly **one docs MCP** per framework, the same pinned model, and per-phase turn caps.
- Every arm implements a **byte-identical `SPEC.md`** — enforced by `harness/sync-spec.sh --check`, not by convention.
- Tokens are read from session transcripts (four buckets reported separately — input, output, cache-write, cache-read — plus estimated list-price cost); the harness, not the agent, verifies build gates and commits phases.
- Code volume is split three ways — app code, native-language source, native configuration — because "wrote 226 lines of Swift" and "wrote 16 lines of plist" are not the same claim.
- Failures are data: capped sessions, failed gates, and acceptance misses are recorded, never silently retried.

Provenance for any published number (model, CLI version, Xcode, MCP versions, auth mode) is recorded per trial in `results/<study>/<trial-id>/manifest.json`.
