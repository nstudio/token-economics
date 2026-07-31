# Token Economics Benchmark Plan — NativeScript vs LynxJS (iOS)

**Question:** How many tokens does an AI coding agent consume to build the *same* iOS app — same UI, same two deep native-platform features — in `ns-benchmark` (NativeScript + Vue 3) vs `lynx-benchmark` (LynxJS + Vue 3 via Sparkling)?

**Hypothesis to test:** NativeScript's direct TypeScript access to iOS APIs should cost fewer tokens than LynxJS, which requires Swift/ObjC native modules plus explicit bridge wiring (typing declarations, method registration, pipe/module plumbing) for the same capabilities. The benchmark measures whether that's true and by how much.

---

## 1. What "token economics" means here (definitions)

The unit of measurement is **one trial**: a fresh, isolated Claude Code session (headless) taking a repo from a tagged baseline to a state that passes a fixed acceptance checklist.

Per trial we capture:

| Metric | Source |
|---|---|
| Input tokens (uncached) | session JSONL `message.usage.input_tokens` summed |
| Output tokens | `message.usage.output_tokens` summed |
| Cache-write tokens | `cache_creation_input_tokens` summed |
| Cache-read tokens | `cache_read_input_tokens` summed |
| Total cost USD | headless `--output-format json` → `total_cost_usd` |
| Turns | `num_turns` |
| Wall-clock | `duration_ms` + JSONL timestamps |
| Tool-call mix | count of `tool_use` blocks by tool name (Read/Edit/Bash/docs-MCP/WebFetch…) |
| Docs friction | # of docs-MCP calls + web fetches |
| Code delta | `git diff --numstat` vs baseline; LOC split JS/TS/Vue vs Swift/ObjC/plist/entitlements |
| Success | build green (hard gate) + functional checklist pass/fail per item |

**Headline numbers:** median total tokens (all four buckets reported separately), median cost USD, median turns, and success rate — per framework, per phase.

Cache-read tokens dominate raw counts in agentic sessions; never report a single collapsed "total tokens" without the bucket breakdown, and always report cost USD alongside (it's the cache-aware scalar).

---

## 2. Baseline state of the two repos (as scanned 2026-07-24)

**ns-benchmark** — stock NativeScript-Vue scaffold: single `Home.vue` ("Blank {N}-Vue app" label), `nativescript-vue` 3.x, `@nativescript/core` 9.1-alpha, Vite bundler, Tailwind 4, no custom native code, iOS deployment target 16.0. Run: `ns debug ios`. Baseline committed 2026-07-25. `@valor/nativescript-websockets` is intentional: it powers Vite HMR, giving a realtime feedback loop usable during agentic development.

**lynx-benchmark** — stock Sparkling ("brownfield") Vue-Lynx template: two demo pages (main + second via `sparkling-navigation`), `vue-lynx` 0.5.1, rspeedy 0.13.3, Lynx 3.6.0 pods, SwiftUI host app `SparklingGo` embedding Lynx via `SPKRouter`, Pods vendored, one custom `LynxUI` element (`LynxInput`), a commented native-method registration example in `SPKServiceRegistrar.swift`, empty `StorageServiceImpl` stub. Build/run: `npm run build` / `npm run run:ios` (sparkling-app-cli). Toolchain decision: **both projects benchmark against Xcode 26** (26.5/17F42 installed); the Podfile's Xcode 26 compatibility patch stays, and `.xcode-version` is updated 16.0 → 26.5 to match.

Both are honest blanks: all app logic and all native bridging for the benchmark remains to be written — which is the work whose token cost we measure.

---

## 3. The benchmark app

### 3.1 The two native iOS features (recommended pair)

Selection criteria: reasonably complex, deep API surface, **works on the iOS Simulator** (mandatory for reproducible verification), and together they exercise the two axes where bridging cost shows up — *permissions/entitlements + async queries with complex data marshaling*, and *streaming callbacks from native into JS*.

**Feature A — HealthKit step dashboard** (`HKHealthStore`)
- Request read+write authorization for step count.
- "Log a walk" action writes an `HKQuantitySample` (e.g. 500 steps, now).
- 7-day daily-totals view via `HKStatisticsCollectionQuery` (per-day sum, unit conversion, date bucketing).
- Exercises: HealthKit **entitlement**, Info.plist usage strings, authorization flow, async query APIs, marshaling an array of `{date, steps}` records back to the Vue layer.
- Simulator-friendly and **deterministically verifiable**: write known samples → read back known totals.

**Feature B — Speech transcription of a bundled audio file** (`SFSpeechRecognizer` + `SFSpeechURLRecognitionRequest`)
- Request speech-recognition authorization.
- Transcribe a known audio clip bundled with the app; **stream partial results** into the UI as they arrive; show final transcript + elapsed time.
- Exercises: permission flow, AVFoundation file handling, and — the key contrast — *repeated* native→JS callbacks (NativeScript: plain closures; Lynx: callback/event plumbing through the module/pipe bridge).
- Simulator-friendly; near-deterministic (known clip → reference transcript, verify ≥90% word match).

Rejected alternatives, for the record: CoreMotion/CoreBluetooth/CoreNFC/CoreHaptics (no simulator support), camera/mic live capture (flaky on simulator), Vision OCR and EventKit (solid backups — Vision is fully deterministic but needs no permissions, and HealthKit already covers the entitlement axis better).

### 3.2 Shared UI spec (parity)

A single framework-neutral `SPEC.md` (committed **identically** to both repos at baseline) defines:

- **Screen topology:** a Home screen with the app title and two navigation affordances → "Health" screen and "Transcribe" screen. (Lynx's template already has 2-page navigation; NS will add it — that asymmetry is real framework economics, not unfairness.)
- **Health screen:** authorization status text, "Request Access" button, "Log 500 steps" button, 7-day list rows formatted `Mon Jul 20 — 1,250 steps`, today's total highlighted.
- **Transcribe screen:** authorization status text, "Transcribe sample" button, live partial-transcript text area, final state showing full transcript + `Completed in N.N s`.
- Exact labels, empty states, error states, and disabled-button rules — pinned so both implementations converge on the same product.
- Styling floor only ("readable spacing, native-feeling list"), no pixel-perfection — we're not measuring CSS golf.

The audio clip ships in both baselines at `spec-assets/sample.wav` (public-domain Harvard-sentences clip) with `spec-assets/reference-transcript.txt`. Getting it *bundled into the app* is part of the measured work for each framework.

---

## 4. Experimental protocol

### 4.1 Repo normalization (one-time pre-work, before any measurement)

1. `ns-benchmark`: ✅ done — Vite migration committed; `@valor/nativescript-websockets` stays (it powers Vite HMR for realtime feedback during development). Verify `ns build ios` is green with Xcode 26.
2. `lynx-benchmark`: ✅ decided — benchmark against **Xcode 26** (26.5/17F42), keeping the Podfile's Xcode 26 patch; `.xcode-version` updated to 26.5. Verify `npm run build` + a simulator build of `SparklingGo.xcworkspace` is green, then commit.
3. ✅ done — `SPEC.md` + `spec-assets/` added identically to both repos (checksum-verified; audio synthesized locally from public-domain Harvard sentences via `say`/`afconvert`).
4. ✅ done — paired `CLAUDE.md` files added with **structurally identical** content (same sections, same level of help): project layout, exact build/run/verify commands, docs sources, native-access mechanism, "iterate until the build passes." Neither gets feature-implementation hints.
5. ✅ done — both repos committed and tagged `benchmark-baseline`; the harness records the toolchain manifest (Xcode, macOS, Node, `claude --version`, docs-MCP version) per trial.

### 4.2 Trial structure — three phased sessions

Each trial = **3 sequential fresh headless sessions** against the same working tree, so token attribution per phase is exact:

- **Phase 1 — UI shell:** both screens + navigation per SPEC §3, placeholder data, build green.
- **Phase 2 — HealthKit:** SPEC §4, build green.
- **Phase 3 — Speech:** SPEC §5, build green.

The harness (not the agent) commits after each green phase with a fixed message (`phase-1`, `phase-2`, `phase-3`), enabling per-phase `git diff --numstat`. Expectation this design tests: Phase 1 costs should be roughly comparable (both are Vue 3); Phases 2–3 are where native-access economics diverge.

Prompt template (identical across frameworks except substitutions):

> You are working in the {framework} app at {repo}. Read SPEC.md. Implement ONLY section {N} ({phase name}). Use the {docs-mcp-name} MCP server for framework/API questions. Build with `{build command}` and fix errors until it succeeds. Do not modify SPEC.md or spec-assets/. Do not implement other sections.

Prompts are stored verbatim in the harness and never edited between trials.

### 4.3 Isolation & fairness controls

- **Fresh identity per session:** run with a dedicated scratch `HOME` (per trial) so no global `CLAUDE.md`, memory, or personal settings leak in — this also means each trial's transcripts land in a private `$HOME/.claude/projects/` we archive wholesale.
- **Pinned model:** same model both sides via `--model`, recorded. (Recommendation: a GA workhorse model — 30 measured sessions on the top-tier model is expensive; the comparison only requires both sides use the *same* model.)
- **MCP parity:** each side gets exactly one docs MCP via `--mcp-config` + `--strict-mcp-config` (nothing else loads): NS → `https://docs.nativescript.org/mcp`; Lynx → `@lynx-js/docs-mcp-server` (https://lynxjs.org/ai/lynx-docs-mcp.html). Record versions. Also record each MCP's tool-schema size — schemas ride in the context every turn and are themselves part of each ecosystem's token economics.
- **Docs-URL parity:** the Lynx docs MCP serves lynxjs.org content only — Sparkling's docs live separately at https://tiktok.github.io/sparkling/. Each repo's CLAUDE.md therefore lists its official doc sources in an identical section (NS: docs.nativescript.org; Lynx: lynxjs.org + the Sparkling docs site). WebFetch stays available to both sides; all doc lookups (MCP + web) are counted as docs friction.
- **Unattended permissions:** `--dangerously-skip-permissions` (runs operate only on these repos; acceptable on a dev machine — or run inside a dedicated macOS user for belt-and-suspenders), plus `--max-turns` cap (calibrate in pilot; start ~80/phase) so a wedged run can't burn unbounded tokens.
- **Reset protocol between trials:** `git reset --hard benchmark-baseline && git clean -fd` with `node_modules/`, `Pods/`, `platforms/` excluded from clean (dependency install time/tokens are not what we're measuring), followed by a scripted baseline build to confirm green before the trial starts.
- **Dev-loop feedback allowed on both sides:** agents may run each framework's dev mode for realtime feedback (NS: `ns debug ios` with Vite HMR via the websockets plugin; Lynx: rspeedy dev flow) — how effectively each side's live loop shortens iteration is legitimate token economics. The phase gate remains a clean full build.
- **Interleaved order:** NS, Lynx, NS, Lynx… to spread time-of-day/API-drift effects.
- **No retries hidden in the data:** every started trial is recorded. A trial that fails acceptance is a *failed trial*, not a discarded one — success rate is a first-class result.

### 4.4 Trial count

- **Pilot:** 1 trial each side. Purpose: calibrate `--max-turns`, shake out spec ambiguities, estimate cost per trial. Pilot data is reported but flagged, since the spec may get amended after it.
- **Main run:** **5 trials per framework** (minimum 3 if budget-constrained). Agent runs are stochastic; medians over ≥5 give directional confidence. Report median + min/max + all raw trials; with n=5 a Mann-Whitney U test is possible but the honest framing is "directional evidence," not p-values.

### 4.5 Acceptance (per trial, after phase 3)

1. **Build gate (automated, hard):** final simulator build succeeds from a clean prepare.
2. **Functional checklist (manual, ~5 min, recorded in the run manifest):**
   - Health: request access → grant → status updates; log 500 steps twice → 7-day list shows today ≥ 1,000; relaunch → data persists (HealthKit store).
   - Transcribe: request access → grant; tap transcribe → partial text visibly streams; final transcript ≥90% word match vs `reference-transcript.txt`; duration shown.
   - UI: both screens reachable, labels match SPEC.
3. **Remediation round (recommended):** if checklist items fail, send exactly **one** standardized follow-up session per trial — "Checklist item {X} fails: {observed behavior}" — with its tokens counted into the trial. Still failing → trial marked failed. This measures the realistic quantity: *tokens to a working app*, while bounding runaway assistance.

XCUITest automation of the checklist is a stretch goal, not v1 — it would add large fixed cost and its own framework-specific flakiness.

---

## 5. Instrumentation & data capture

Per session, the harness records:

1. **Headless summary:** `claude -p "$(cat prompt.md)" --output-format json …` → `total_cost_usd`, `num_turns`, `duration_ms`, `usage` buckets, `session_id`, final result text.
2. **Full transcript:** the session JSONL from the scratch `$HOME/.claude/projects/…/<session_id>.jsonl` — per-message `usage` (the four token buckets) and every `tool_use` block. This is the ground truth for analytics; the harness archives it per phase.
3. **Repo evidence:** per-phase git commit, `git diff --numstat`, list of files touched.
4. **Run manifest (JSON):** trial id, framework, phase, timestamps, model id, CLI version, MCP config + versions, max-turns, checklist results, operator notes.

Directory layout:

```
token-economics/
  PLAN.md                  ← this file
  harness/
    prompts/               phase-1.md, phase-2.md, phase-3.md (with {placeholders})
    mcp/                   ns.mcp.json, lynx.mcp.json
    spec/                  SPEC.md, spec-assets/   (copied into both baselines)
    run-trial.sh           orchestrates: reset → 3 phases → archive
    analyze.mjs            JSONL → per-trial CSV + summary JSON
  results/
    <trial-id>/            manifest.json, phase-N.summary.json, phase-N.jsonl, diffs/
    summary.csv
    REPORT.md              final write-up + charts
```

> **Layout note (2026-07-31):** when a second study was added, the harness became registry-driven and results
> were namespaced per study — this study's artifacts now live under `results/ns-vs-lynx/`, its spec under
> `harness/spec/v1.0/`, and runners take a study slug (`./run-trial.sh ns-vs-lynx ns …`). Every file moved as a
> pure rename; all 361 archived artifacts are byte-identical and every published number re-verified against the
> pre-move output. See [`harness/README.md`](harness/README.md) for the current structure and
> [`PLAN-EXPO.md`](PLAN-EXPO.md) for the second study's design.

(Alternative capture path: Claude Code's OpenTelemetry metrics export. Strictly optional — JSONL parsing is self-contained, offline, and reproducible from archived artifacts alone.)

`analyze.mjs` responsibilities: sum usage buckets per session; tool-call histogram (flag docs-MCP calls and WebFetch separately); wall time; LOC added split by extension class (`.vue/.ts/.css` vs `.swift/.h/.m/.plist/.entitlements/xcodeproj`); emit `summary.csv` (one row per trial×phase) and aggregate medians. Charts generated from the CSV for `REPORT.md` — token totals by framework×phase, cost, turns, tool mix, native-vs-JS LOC.

---

## 6. Known confounders (disclose in the report, don't hide)

1. **Training-data familiarity.** NativeScript (2014) is far better represented in model training data than Lynx (2025). Some NS advantage may be "the model already knows it" rather than "the architecture needs fewer tokens." Mitigation: both sides get docs MCPs; report docs-lookup counts. But this can't be fully removed — disclose it as inherent to *practical* token economics today.
2. **Docs quality differences** are part of what's being measured (they're real economics), not noise to eliminate.
3. **MCP schema overhead** differs per server and rides in context every turn — measured and reported (see §4.3).
4. **Alpha toolchain risk:** ns-benchmark rides 9.1-alpha CLI/runtime; lynx-benchmark needed a Podfile patch for Xcode 26. Toolchain-fighting tokens are legitimate data *if* the baseline builds green — hence the hard pre-work rule that both baselines build before tagging.
5. **Stochasticity:** temperature isn't controllable in Claude Code; handled by N≥5 trials, medians, and full raw-data disclosure.
6. **Sparkling ≠ raw Lynx:** this measures Lynx *via Sparkling* — a deliberate choice, not an accident. Sparkling is one of the two production paths the Vue Lynx quick start offers and the only productized one (CLI-scaffolded host, routing, type-safe JS↔Native bridge with codegen — the "Expo of Lynx"), making it the fair framework-vs-framework analog to NativeScript and the path a real Vue Lynx team would take. The agent may use Sparkling's `MethodRegistry`/pipe (or raw `LynxModule` registration — whichever it discovers); that discovery is part of the measurement. Sparkling is public beta, so its toolchain fragility is fenced off by the baseline-builds-green gate (§4.1). Title the report "LynxJS via Sparkling"; a raw direct-integration condition is possible future work, not v1.

---

## 7. Execution order

| Step | What | Output | Status |
|---|---|---|---|
| 0 | Repo normalization + baseline tags + toolchain manifest (§4.1) | two green, tagged baselines | ✅ 2026-07-25 |
| 1 | Author SPEC.md, prompts, MCP configs, `run-trial.sh`, `analyze.mjs` | harness/ | ✅ 2026-07-25 |
| 2 | Pilot: 1 trial each; calibrate max-turns; fix spec ambiguities; estimate $/trial | pilot data + frozen spec | ✅ 2026-07-25 — see `results/REPORT.md` (calibration: MAX_TURNS→160, MCP fixes, app archiving); interactive acceptance pending |
| 3 | Main run: 5 trials × 2 frameworks, interleaved (`harness/run-main.sh 5`) | results/ | ✅ 2026-07-25 — 10/10 trials, 30/30 phases build-green; one infra-invalid pair-5 attempt (auth rotation) caught at preflight and re-run |
| 4 | Analysis + REPORT.md (+ optional shareable dashboard) | the answer | ✅ 2026-07-25 — final n=5 analysis in `results/REPORT.md`; acceptance checklist + any remediation still pending to close the study |

## 8. Extension: runtime performance benchmarks (added 2026-07-25)

Token cost answers *what it costs to build*; this extension answers *what you get* — how the finished products perform. Methods:

**No new agent trials.** Performance is a property of the built artifact, not the agent's path to it. The corpus is the 10 main-run implementations, whose final source trees are preserved as `trials/main-*` git branches (from the per-phase `end_sha` in each manifest). Measuring all 5 implementations per framework also captures *implementation variance* — different agent solutions to the same spec may perform differently, and one app per side would hide that.

**Release builds only** (`harness/perf/build-release.sh`): each trial branch is checked out, built in Release configuration, and archived under `results/<id>/app-release/`. Debug builds are never measured — they carry dev-only weight (unoptimized code; Lynx's DevTool/DebugRouter attach). Note: the Sparkling template ships LynxDevtool/DebugRouter pods in Release too (no `:configurations` gating) — measured as-shipped, with the Devtool share quantified separately in the size breakdown so readers can subtract it.

**Measured per app** (`harness/perf/measure.sh`, one fixed simulator, interleaved ns/lynx order, sequential):
- **Size:** bundle bytes, main-executable bytes, per-framework breakdown, installed-container bytes.
- **Cold launch × 5:** app terminated between runs; T0 taken immediately before `simctl launch`; end markers parsed from a `log stream` capture of SpringBoard/FrontBoard/runningboardd (launch-complete / foreground-active), with a CPU-settle fallback (first 600 ms window where process CPU stays <5%). The marker actually used is recorded per trial (`launch_source`).
- **Idle steady state:** after a 12 s settle — RSS and `phys_footprint` (memory), plus %CPU sampled 10×1 s (median + max; catches background churn like DebugRouter polling).

**Feature-path latency (automated):** a generic XCUITest driver (`harness/perf/uidriver/`) drives every Release app through the real HealthKit and Speech flows by tapping SPEC-pinned labels (which is what makes one driver work across all implementations) — agent-built apps are never modified. Per app, 3 iterations, fresh launch each: nav→screen-rendered (both screens), 7-day query→rows, log-500→list-refresh, transcribe→`Completed in`. Permission sheets are auto-granted (HealthKit sheet + speech alert). Batch: `harness/perf/run-interactions.sh`; aggregation: `analyze-interactions.mjs`. Known bounds: speech recognition is simulator-blocked (Siri infrastructure absent — fails identically on both frameworks; device-only metric, captured by the operator from the app's own `Completed in N.N s` display), and back-navigation isn't a pinned label so driver coverage can vary per implementation (gaps recorded, never silently dropped).

**JS↔native interop microbenchmarks (added same day; hand-written, separate from the agent-built corpus):** modeled on NativeScript's historical perf-metrics posts (primitives loop / string calls / big-data marshalling against a native `TestFixtures` class), extended symmetrically. Bench apps live on the `interop-bench` branch of each framework repo, hand-authored — this measures framework physics, not agent behavior, so agent-built artifacts are untouched. Design guarantees:
- **Identical scenario code** on both sides (same iteration counts, same data), self-timed in-app via `Date.now()`, rendered as an `INTEROPJSON:` payload that the capture driver reads off the accessibility tree. Every scenario emits a `check` value; the analyzer verifies checks match across frameworks — proof the workloads are identical.
- **Equivalent native fixture both sides** (`add(a,b,c)`, `strLen(s)`, `sumBytes(s)`): NativeScript reaches it by direct binding (an ObjC class in `App_Resources/iOS/src` — note: requires a `module.modulemap` beside the header for metadata generation); Lynx reaches it through an authored Swift `LynxContextModule` registered on the page context. The asymmetry in *how* JS reaches native **is the architecture under test**; the fixture work is identical.
- **Scenarios:** `js_compute` (2M-iteration math loop — pure engine: V8 vs PrimJS), `json_roundtrip`, `prim_latency`/`str_latency` (1,000 sequential native calls — per-call round-trip latency; NS synchronous binding vs Lynx async bridge, each framework's idiomatic path), `prim_burst` (10,000 calls in flight — bridge throughput), `marshal_1mb` (1 MB string across the boundary), and the "dial to native" pair `checksum_js` vs `checksum_native` (same byte-sum over 1 MB, pure JS vs native-via-interop — directly testing the claim that slow paths can be rewritten in native and called from JS, on *both* frameworks).
- **Protocol:** Release builds, one fixed long-lived simulator, N interleaved runs per framework (`harness/perf/run-interop.sh`, medians via `analyze-interop.mjs` → `results/perf/interop-summary.json`). Disclosures: Lynx runs JS off-main-thread and NS on-main — self-timed totals make that fair but it's stated; async bridge latency inherently includes runloop scheduling (that *is* its cost); simulator-not-device as ever.

**Honest limits of this extension:** iOS **Simulator on one Mac** — absolute numbers are not device numbers; only the *comparative* readings matter, and they share host, simulator runtime, and interleaved scheduling. No scroll/FPS metric: the spec'd app has no scroll-stressing surface (7-row list), and synthetic scroll would measure a UI we didn't build. Analysis: `harness/perf/analyze-perf.mjs` → `results/perf/summary.json`; findings in `results/REPORT.md` §Performance.

## 9. Open decisions (recommendations inline)

1. **Model for measured runs** — recommend one GA workhorse model for all 30+ sessions (identical both sides); top-tier model optional as a second condition later.
2. **N** — recommend pilot 1+1, then 5+5.
3. **Feature pair** — recommend HealthKit + Speech as specced; Vision OCR and EventKit are the vetted substitutes if either proves problematic in pilot.
4. **Remediation round** — recommend allowing exactly one, tokens counted (§4.5).
5. **Keep or drop the Lynx `second` demo page at baseline** — recommend keep both repos as-scaffolded; template asymmetries are part of each framework's real starting economics.
