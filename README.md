# Token Economics: NativeScript vs LynxJS (iOS)

How many tokens does an AI coding agent consume to build the **same iOS app** — same spec, same UI, two deep native-platform features (HealthKit + Speech) — in **NativeScript + Vue 3** versus **LynxJS + Vue 3 (Sparkling host)**?

NativeScript calls iOS APIs directly from TypeScript; LynxJS requires Swift/ObjC native modules and explicit bridge wiring. This project measures what that architectural difference costs in agent tokens, using fresh, isolated, headless Claude Code sessions under a controlled protocol.

**Results site:** [agent-tokenomics](https://github.com/nstudio/agent-tokenomics) — interactive charts, methodology, and reproduction guide, generated from this repo's raw data.

## Layout

| Path | What |
|---|---|
| `PLAN.md` | **Methods** — full experimental design: definitions, protocol, controls, confounders |
| `apps/ns-benchmark/` | NativeScript-Vue baseline — the exact blank start state every NS trial reset to |
| `apps/lynx-benchmark/` | LynxJS/Sparkling baseline — same, for Lynx trials |
| `apps/trials/` | Every main-run trial's final source tree, exported (what each agent actually built) |
| `apps/interop-bench/` | Hand-written JS↔native interop microbenchmark apps (identical scenarios + equivalent native fixture per framework) |
| `harness/` | Runner + analyzers, token and performance suites — see `harness/README.md` |
| `harness/spec/` | Canonical `SPEC.md` (the app spec both frameworks implement) + fixed assets |
| `results/` | One directory per trial: manifest, full session transcripts (JSONL), diffs, build logs |
| `results/REPORT.md` | **Findings** — the results write-up |
| `results/perf/` | Runtime performance measurements (size, launch, memory, API-path latency) |

Note: trial `.app` binaries are not committed (~3 GB); rebuild any trial's app from its source in `apps/trials/` via `harness/perf/build-release.sh`.

## Reproduce

```sh
cd harness
./run-trial.sh ns my-trial-1        # one trial (3 phased headless sessions + build gates)
./run-main.sh 5                     # full main run: 5 interleaved ns/lynx pairs
node analyze.mjs                    # summary.csv / summary.json + median tables
```

Requirements: macOS with Xcode 26.5, Node 22+, Claude Code CLI, an iOS Simulator, and Claude subscription or API key (auth is handled automatically — see `harness/README.md`).

## Key measurement principles

- Every session runs **fresh and isolated** (throwaway `CLAUDE_CONFIG_DIR`: no personal settings, memory, or global instructions) with exactly **one docs MCP** per framework, the same pinned model, and per-phase turn caps.
- Tokens are read from session transcripts (four buckets reported separately — input, output, cache-write, cache-read — plus estimated list-price cost); the harness, not the agent, verifies build gates and commits phases.
- Failures are data: capped sessions, failed gates, and acceptance misses are recorded, never silently retried.

Provenance for any published numbers (model, CLI version, Xcode, MCP versions, auth mode) is recorded per trial in `results/<trial-id>/manifest.json`.
