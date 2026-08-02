# Results — Token Economics: NativeScript vs LynxJS (iOS)

Living document. Methods: see [`../../PLAN.md`](../../PLAN.md). Runner details: [`../../harness/README.md`](../../harness/README.md).
**Shareable results page (charts + self-contained methodology):** https://claude.ai/code/artifact/c1ba1864-3fdb-48e6-afcb-fb067da34bf2 — private by default; share from the page's menu.

**Status (2026-07-25):** pilot + full main run complete — **10/10 trials, 30/30 phases build-green, n=5 per framework** — and the **runtime performance extension is measured** (Release rebuilds of all implementations; see §Performance). Remaining: operator interactive acceptance (apps archived per trial), which finalizes success rates, remediation tokens, and interaction-path perf notes.


---

## Correction (2026-08-02) — the app-size finding was wrong, and reverses

**What was wrong.** App size came from the `Release-iphonesimulator` `.app` directory, which carries
an x86_64 slice that never ships and full symbol tables. This penalised LynxJS far more than
NativeScript: its DevTool/DebugRouter stack was counted fat and unstripped at 23.6 MB, where a device
archive puts it at 5.3 MB.

**What changed.** Re-measured as unsigned arm64 device archives, LynxJS is **smaller** than
NativeScript rather than 50% larger. The conclusion reverses, and the latency write-up no longer
claims footprint as NativeScript's runtime edge — its remaining edge is idle memory. What survives is
the narrower finding that the Sparkling template ships DevTool in Release at all; only its weight was
overstated.

| Figure | As published | Corrected |
|---|---|---|
| NativeScript bundle | 93.3 MB | **51.1 MB** (n=1 reference, see below) |
| LynxJS bundle | 140.2 MB | **26.1 MB** (n=4, no variation) |
| LynxJS DevTool stack | 23.6 MB | **5.3 MB** |
| Headline gap | +50% | **−49%** |

**Provenance limit on the NativeScript arm.** This study predates study-scoped trial branches. Its
NativeScript trees were committed as `trials/main-ns-N`, and the 2026-08-01 `ns-vs-expo-buildonly`
run reused those exact names and force-updated them, so the 2026-07-25 trees are gone. Token results
are unaffected — they come from archived transcripts — but that arm cannot be rebuilt from source.
Recorded in `harness/studies/ns-vs-lynx.json` as `lostTrialTrees`; branch resolution now refuses to
guess a flat name rather than silently measure another study's tree. The one surviving spec-v1.0 tree
(`cc1f065`) is measured as `ref-ns-v1.0` and lands at 51.1 MB — identical to all 8 NativeScript
archives in the companion Expo study — so the substitution does not move the number.

`main-lynx-5` fails the device archive with the same "Multiple commands produce sample.wav" error it
fails Release with, so the device corpus matches the published one. Per-trial data:
`perf/device/*.json`.

---

## Pilot (2026-07-25) — `pilot-ns-1` / `pilot-lynx-1`

Model `claude-sonnet-5`, `MAX_TURNS=80` per phase (pilot value — see calibration below), subscription auth, Xcode 26.5 (17F42). All six phases ended with green build gates.

### Numbers

| Phase | NativeScript | LynxJS | Signal |
|---|---|---|---|
| 1 — UI shell | $1.50 · 13.2k out · 55 turns | $2.48 · 22.3k out · 71 turns | Lynx ~1.7× output |
| 2 — HealthKit | $3.73 · 36.9k out · uncapped | $5.80 · 67.5k out · **capped** | Lynx ≥1.8× output |
| 3 — Speech | $4.02 · 30.9k out · **capped** | $3.85 · 35.7k out · **capped** | ~even (both truncated) |
| **Total** | **$9.24 · 81.0k output** | **$12.13 · 125.6k output** | **Lynx ~1.55× output, ~1.3× cost** |

Cache traffic: NS 355.7k cache-write / 19.5M cache-read; Lynx 480.2k / 24.5M. Costs are estimated list-price (subscription auth). Full per-phase rows: `summary.csv`; raw artifacts per trial directory.

**Native-vs-JS code split** (lines added): NativeScript wrote **14 native-side lines**, all of them Info.plist/entitlements config — **zero lines of native-language code**; all feature logic stayed in TypeScript. LynxJS wrote **298** native-side lines: **282 of Swift** plus 16 of config. This is the benchmark's core structural signal, and it showed up on the first trial.

**Docs usage:** NS made 21 docs-MCP calls; Lynx made 7 MCP resource reads (its docs MCP is resources-based) and leaned much harder on Bash (135 calls vs NS 113 — notably grepping vendored Pods/Sparkling sources for bridge answers).

### Read with caution

- **n=1 per side** — directional only; medians come from the main run.
- **3 of 6 phases hit the 80-turn cap** (Lynx phases 2–3, NS phase 3). Their numbers are *floors*; since Lynx was truncated twice, the true gap is likely understated.
- Pilot numbers are **not comparable to main-run numbers** (different turn cap).

### Smoke acceptance (automated portion)

Both pilot apps install, launch, and render the SPEC §3.1 home screen exactly (title, subtitle, both buttons) — screenshots: `pilot-ns-1/home.png`, `pilot-lynx-1/home.png`. Lynx bundle includes all three `.lynx.bundle` pages and `sample.wav`; Info.plist carries correct HealthKit/Speech usage strings.

⚠️ Operational note: the Lynx app's real bundle id is **`io.nstudio.lynx`** (the Xcode project's setting), not the `com.example.sparkling.go` in `app.config.ts` — use `xcrun simctl launch <sim> io.nstudio.lynx`.

Interactive items (permission flows, step logging + persistence, transcription streaming + ≥90% word match, deny paths) — **pending operator run**, to be recorded in each trial's `manifest.json` under `acceptance`.

### Harness calibration from the pilot

1. `MAX_TURNS` default raised **80 → 160** (80 demonstrably truncates native phases).
2. Lynx docs MCP is a **resources** server (no MCP tools; docs read via `lynx-docs://` resources) — analyzer now counts resource reads as docs lookups; server launched from a locally installed pinned copy (0.2.4) instead of `npx` to eliminate cold-start races.
3. Analyzer surfaces a `capped` column per phase.
4. Runner now archives each trial's built `.app` under `results/ns-vs-lynx/<trial-id>/app/` so acceptance can run (via `simctl install`) even after later trials reset the repos.

---

## Main run (2026-07-25) — FINAL, n=5 per framework

`./run-main.sh 5`, interleaved `main-ns-1..5` / `main-lynx-1..5`, `claude-sonnet-5`, `MAX_TURNS=160`, subscription auth, Xcode 26.5. **All 30 phases across 10 trials ended build-green.** Only **1 of 30 phases hit the turn cap** (`main-lynx-3` phase 2: 161 turns, $15.61, 69 min — retained; capped numbers are floors), confirming 160 is calibrated. Pilot rows are excluded from all medians below (different cap). Format: **median (min–max)**.

### Headline result

**Building the identical app cost the agent ~1.9× the output tokens and ~2.4× the estimated dollars on LynxJS versus NativeScript — and the per-trial ranges do not overlap** (worst NS trial 95.9k output tokens vs best Lynx trial 139.7k).

| Per trial (phases 1–3) | NativeScript | LynxJS | Ratio |
|---|---|---|---|
| Output tokens | **81.7k** (77.5–95.9k) | **153.1k** (139.7–193.6k) | **1.9×** |
| Est. cost (list price) | **$7.52** ($5.27–10.51) | **$18.29** ($15.42–25.93) | **2.4×** |
| Turns | 218 (157–295) | 350 (320–405) | 1.6× |
| Wall time | ~22 min (17–30) | ~39 min (35–94) | 1.7× |
| Cache-read tokens | 15.5M (8.5–22.6M) | 41.4M (30.8–61.7M) | 2.7× |
| Native-side LOC added | **16** (15–17) | **242** (235–421) | **~15×** |
| — of which native-language code | **0** (0–0) | **226** (213–405) | — |
| — of which native config | 16 (15–17) | 18 (16–23) | ~1× |
| JS/TS-side LOC added | 376 (327–396) | 392 (335–503) | ~1× |

The LOC split is the mechanism in one row, and the three-way breakdown (added 2026-07-31, see the addendum below) makes it exact: both frameworks wrote essentially the same amount of Vue/TS **and the same native configuration**, but Lynx additionally authored ~226 lines of Swift per trial while NativeScript authored **none** — and that authorship plus the discovery around it roughly doubles total token spend.

### Per-phase medians (output tokens · cost · turns)

| Phase | NativeScript | LynxJS | Output ratio |
|---|---|---|---|
| 1 — UI shell | 12.9k · $1.29 · 54 | 22.5k · $2.56 · 76 | 1.7× |
| 2 — HealthKit | 52.8k · $5.14 · 124 | 67.5k · $6.63 · 133 | 1.3× |
| 3 — Speech | **15.4k · $1.21 · 39** | **61.7k · $7.86 · 154** | **4.0×** |

**Phase 3 is the headline mechanism, at 4.0×:** NativeScript's third phase was its *cheapest* — the agent had learned the direct-TypeScript platform-access pattern in phase 2 and simply reused it for `SFSpeechRecognizer` (~2 native LOC, config only). Lynx had to build a *second* complete Swift module + Sparkling bridge registration + streaming-callback plumbing (median 108 native LOC), so its phase 3 stayed as expensive as its phase 2. **Bridging cost recurs per native feature; direct-access cost amortizes after the first.** NS phase-2-to-3 dropped 71% in output tokens; Lynx dropped 9%.

Phase 2's tighter ratio (1.3×) understates the gap slightly: it contains the one capped Lynx phase (floor), and Lynx phase-2 variance was wide (55–113k) versus NS's tight 47–60k. Phase 1's 1.7× on identical Vue 3 work is consistent with ecosystem maturity/training-data familiarity (disclosed confounder, PLAN §6.1).

### Docs friction

NS agents leaned on the NativeScript docs MCP (median 22 calls/trial, range 14–27); Lynx agents made few docs reads (median 10.5 — its MCP is resources-based) and instead grepped vendored Pods/Sparkling sources via Bash — a workable but token-hungry discovery path visible in the 2.7× cache-read gap.

### Reliability & provenance

10/10 trials fully green; zero remediation rounds used so far (acceptance pending). One capped phase (`main-lynx-3` ph2). One infra event: the subscription OAuth token rotated after pair 4; both pair-5 first attempts failed at **preflight** (zero measured tokens), were preserved as `main-*-5.infra-invalid`, and re-ran clean after re-login — exactly the infra-invalid protocol from the plan. Per-trial provenance in each `manifest.json`; raw rows in `summary.csv`/`summary.json`.

## Performance (2026-07-25) — Release builds, 9 of 10 apps

Token cost measures what it costs to *build*; this section measures what you *get*. Methods in [`../../PLAN.md`](../../PLAN.md) §8 — in brief: **no new agent trials** (performance belongs to the artifact, not the agent's path); every main-run implementation was reconstructed from its preserved `trials/*` branch, rebuilt in **Release** configuration, and measured on one fixed simulator (iPhone 17 Pro, Xcode 26.5), interleaved, quiet host: full size breakdown, 5 cold launches each, and idle steady-state sampling. Raw per-trial JSON: `perf/`; aggregation: `harness/perf/analyze-perf.mjs`.

**Corpus note (a finding in itself):** 5/5 NativeScript implementations built in Release untouched. **4/5 Lynx did** — `main-lynx-5` fails Release with *"Multiple commands produce sample.wav"* (that agent wired the audio asset through two copy mechanisms; Debug tolerated it, Release's stricter build graph doesn't). Patching it would invalidate the artifact, so it's excluded and recorded. That failure mode is characteristic of the heavier resource-wiring path.

### Results (median across apps; ranges in `perf/summary.json`)

> **The four size rows below are superseded — see the Correction at the top of this file.** They are
> simulator measurements, which carry an x86_64 slice that never ships and full symbol tables. On an
> arm64 device archive: NativeScript **51.1 MB**, LynxJS **26.1 MB** (**−49%**, i.e. the sign flips),
> DevTool stack **5.3 MB**. The launch, memory, and latency rows are unaffected.

| Metric (Release, simulator) | NativeScript (n=5) | LynxJS (n=4) | Δ |
|---|---|---|---|
| ~~App bundle on disk~~ *(superseded)* | ~~93.3 MB~~ | ~~140.2 MB~~ | ~~+50%~~ |
| ~~— main executable~~ | ~~23.4 MB~~ | ~~4.6 MB~~ | app code lives in JS+frameworks on Lynx |
| ~~— frameworks~~ | ~~68.1 MB~~ | ~~134.9 MB~~ | ~~2×~~ |
| ~~— of which DevTool/DebugRouter~~ | 0 | ~~23.6 MB~~ | ships in Release per Sparkling template |
| ~~Bundle ex-DevTool~~ | ~~93.3 MB~~ | ~~116.7 MB~~ | ~~+25%~~ |
| Cold launch → foreground-active | 316 ms | 317 ms | **~equal** |
| Launch work settle (CPU quiesce) | 1.53 s | 1.64 s | +7% Lynx |
| Idle memory (RSS) | **215 MB** | **288 MB** | **+33% (+72 MB)** |
| Idle memory (phys footprint) | 38 MB | 48 MB | +26% |
| Idle CPU | 0.0% | 0.0% | both clean — no background churn |

### Reading it

- **Size is the decisive gap.** The Lynx runtime stack (Lynx + PrimJS + LynxService + SDWebImage + Sparkling + …) roughly doubles framework weight; NativeScript's V8-based runtime is heavier per-executable but lighter overall. Even crediting Lynx the full DevTool subtraction (a Podfile fix any shipping team would make), it stays +25%.
- **Memory tracks size.** +72 MB resident at idle on the same home screen, with both footprint metrics agreeing on direction. Idle CPU is zero on both — the Release DebugRouter is dormant, not polling.
- **Launch is effectively a tie at OS level** (~316 ms to foreground-active on this Mac-hosted simulator), with Lynx doing ~7% more total launch-burst work — consistent with booting more framework machinery, but small.
- **Implementation variance is negligible** — across 5 (resp. 4) independently agent-built apps, bundle size varies by <0.4 MB, launch by <6 ms, RSS by <8 MB. Runtime performance is a property of the framework, not of how the agent wrote the app — the frameworks differ for the *builder* (tokens), far less for the *runtime*, size and memory aside.

### Feature-path latency — using the platform APIs (added same day)

The direct answer to "sure, NativeScript costs fewer tokens, but LynxJS will perform better": we measured it. A generic XCUITest driver (`harness/perf/uidriver/`) drives every Release app through the actual HealthKit and Speech flows by tapping the SPEC-pinned labels — agent-built apps untouched — timing tap→UI-observable-result. 3 iterations per app, fresh app launch per iteration, permission sheets auto-granted, same fixed simulator as all other perf metrics. Raw: `perf/interactions/`; aggregation: `harness/perf/analyze-interactions.mjs`.

| Tap → result (median ms, range) | NativeScript | LynxJS | Read |
|---|---|---|---|
| Nav → Health screen rendered | 1,903 (1,784–2,216) | 1,785 (1,769–1,819) | ~tie, Lynx tighter |
| 7-day HealthKit query → rows rendered | 1,059 (1,033–1,081) | 1,085 (1,070–1,113) | **tie (2% apart)** |
| Log 500 steps → list refreshed | 643 (385–647) | 447 (441–447) | **Lynx ~30% faster** |
| Nav → Transcribe screen rendered | 1,874 (1,706–2,188) | 1,758 (1,733–1,782) | ~tie, Lynx tighter |
| Transcription (tap → `Completed in`) | blocked | blocked | see below |

**What this says, honestly stated both ways:**

- **The platform-API invocation paths are effectively equivalent.** The heavy read path (statistics query + marshal + render) is a dead tie — HealthKit itself dominates, and neither NativeScript's direct calls nor Lynx's Swift bridge adds visible cost against it.
- **Lynx wins one metric**: the write→refresh round trip (447 vs 643 ms median, and remarkably consistent). Worth noting: the single fastest app overall was a NativeScript one (`main-ns-5`, 385 ms), and NS's wide range (385–647) traces to differing agent refresh strategies — so this is partly implementation choice, not pure framework ceiling. Either way, the "bridge tax" is **not** a practical latency penalty on these paths.
- **No metric materially favors NativeScript at runtime.** ~~Its runtime edge is size (+50%) and idle memory (+33%), not speed.~~ **Corrected 2026-08-02:** size does not favor NativeScript — on a device archive LynxJS is 49% smaller. Its remaining runtime edge is idle memory (+34%), not speed and not footprint.
- **Verdict on the adversarial claim:** "LynxJS will perform better" is *not supported* as a general statement — feature-path latency is a wash (one modest Lynx edge), launch is a tie, and Lynx pays real size/memory costs. Symmetrically, "NativeScript is faster at runtime" is not supported either. The decisive, non-wash difference in this study is **build cost (1.9× tokens)**, favoring NativeScript. ~~and footprint (+50% disk, +33% memory)~~ — **corrected 2026-08-02:** disk footprint favors *LynxJS* (−49% on a device archive); only idle memory (+34%) favors NativeScript.

**Speech is simulator-blocked, identically for both frameworks:** all 27 iterations across all 9 apps failed with "Failed to initialize recognizer" — `SFSpeechRecognizer`'s server path rides Siri infrastructure that iOS Simulators don't provide. Every app surfaced the error in its status line per spec (correct behavior, both frameworks). Transcription latency therefore needs a physical device: each app displays `Completed in N.N s` on screen, so it's a 2-minute operator capture per app when a device is available — recorded then under `acceptance.perf_notes`.

**Coverage disclosure:** back-navigation isn't a spec-pinned label, and two Lynx implementations use a back affordance the driver doesn't match (`goHome failed` — their Transcribe metrics are missing); two apps' list-refresh detection didn't register on their row structure. Per-metric n is 5+4, 5+3, 4+3, 5+2 (NS+Lynx); all gaps are recorded in the raw JSON, none silently dropped.

### JS↔native interop microbenchmarks (added same day) — the "dial to native" test

Feature-path timings above are OS-API-dominated; this suite isolates the framework layers themselves, modeled on NativeScript's historical perf-metrics posts and extended symmetrically. **Hand-written bench apps** (not agent-built — this measures framework physics): identical scenario code on both sides, an equivalent native fixture each (`add`/`strLen`/`sumBytes` — ObjC class via direct binding on NS, authored Swift `LynxContextModule` on Lynx), self-timed in-app, every scenario emitting a `check` value that must match across frameworks (all 8 do — the workloads are provably identical). Release builds, 3 interleaved runs + a verification run rebuilt from the committed sources (reproduced within noise). Sources: `apps/interop-bench/`; raw: `perf/interop/`; medians:

| Scenario | NativeScript (V8) | LynxJS (PrimJS) | Ratio |
|---|---|---|---|
| `js_compute` — 2M-iteration math loop | 57 ms | 271 ms | **4.8×** |
| `json_roundtrip` — 500 × 100-key object | 4 ms | 17 ms | 4.3× |
| `prim_latency` — 1,000 sequential native calls | 1 ms (**~1 µs/call**) | 130 ms (**~130 µs/call**) | **~130×** |
| `str_latency` — 1,000 × 100-char string calls | 1 ms | 131 ms | ~131× |
| `prim_burst` — 10,000 calls in flight | 5 ms | 1,191 ms | 238× |
| `marshal_1mb` — 1 MB string across, per call | 1.0 ms | 2.0 ms | 2× |
| `checksum_js` — byte-sum 1 MB ×3, pure JS | 74 ms | 444 ms | 6× |
| `checksum_native` — same, native via interop | **3 ms** | **9 ms** | 3× |

**Readings, honest in both directions:**

1. **"Dial to native" is real on *both* frameworks.** The same task moved from JS to native got 24× faster on NativeScript (74→3 ms) and **49× faster on LynxJS** (444→9 ms). Any hot path can be rewritten natively and called from JS on either side — Lynx included.
2. **The cost of *reaching* native differs by two orders of magnitude.** NS direct bindings cost ~1 µs per call; Lynx's async module bridge ~130 µs (and pipelining 10k calls doesn't amortize it — ~119 µs/call in flight). This is the "bridge tax," and it matters for chatty per-item native access while washing out entirely for bulk transfers (1 MB marshalling: 2×, near-parity) and coarse-grained calls like the feature paths measured above.
3. **The engines differ too:** identical JS runs ~5× faster on V8 (NS) than PrimJS (Lynx) in these compute/JSON workloads. PrimJS optimizes for startup footprint, not throughput — a real trade both frameworks' users inherit.
4. **Practical synthesis:** neither framework is slow *if used to its architecture* — Lynx wants coarse-grained, batched native calls and native code for hot loops; NativeScript tolerates fine-grained native chatter and lets pure TS go further before dropping to native (and reaching native requires no bridge authoring). The earlier tap-to-result tie shows both idioms deliver equivalent real-app feature latency.

Disclosures: Lynx runs JS off-main-thread, NS on-main (self-timed totals make that fair; stated). Async bridge latency includes runloop scheduling — that *is* its cost, not overhead we failed to subtract. Simulator on one Mac, comparative readings only. NS gotcha recorded for replicators: custom classes in `App_Resources/iOS/src` need a `module.modulemap` beside the header or the metadata generator silently skips them.

### Limits

Simulator on one Mac: absolute numbers are not device numbers — only the comparative readings transfer, and they share host, simulator runtime, and interleaved scheduling. Sizes are uncompressed simulator builds (no App Store thinning/compression). No scroll/FPS metric — the spec'd app has no scroll-stressing surface, and Lynx's multithreaded-rendering pitch targets exactly that kind of load; that claim is explicitly untested here rather than quietly folded in. Feature-path timings measure tap→UI-observable result via the accessibility tree (includes each framework's render+a11y latency — which is what a user experiences).

## Addendum (2026-07-31) — two new measures over the same evidence

Preparing the second study ([`../../PLAN-EXPO.md`](../../PLAN-EXPO.md)) added two analyzer measures that apply retroactively. **No measured value in this report changed**: both are new derived views of the identical archived transcripts and diffs, recomputed by `harness/analyze.mjs` and verified against the pre-refactor output at 900/900 legacy cells. Evidence integrity is checkable with `node harness/manifest.mjs ns-vs-lynx --check`.

### 1. Native-side LOC now splits code from configuration

The original single "native-side" bucket mixed two different kinds of work: writing Swift, and writing an Info.plist key. Splitting them sharpens the headline considerably.

| Per trial, median (main run, n=5) | NativeScript | LynxJS |
|---|---|---|
| Native-**language** code (`.swift`) | **0** | **226** |
| Native **config** (plist/entitlements) | 16 | 18 |
| Total native (as originally published) | 16 | 242 |

Per phase, the config work is not merely similar — it is **identical**:

| Phase | NS code / config | Lynx code / config |
|---|---|---|
| 1 — UI shell | 0 / 0 | 0 / 0 |
| 2 — HealthKit | **0 / 14** | 134 / **14** |
| 3 — Speech | **0 / 2** | 106 / **2** |

Both agents wrote the same 14 lines of HealthKit entitlement/usage-string config, then the same 2 lines for Speech. Every remaining native line on the LynxJS side is Swift the agent had to author, register, and debug. The precise claim is therefore stronger than the original "16 vs 242": **reaching these two platform APIs required the same platform configuration on both frameworks, and 226 lines of Swift on exactly one of them.**

### 1a. Correction — generated lockfiles no longer count as authored code

Preparing the Expo arm surfaced that `package-lock.json` / `Podfile.lock` / `Gemfile.lock` churn was being counted as JS/TS LOC. A dependency resolver writes those files; counting them credits `npm install` as authorship, and the effect scales with how many packages a framework's idiom pulls in — one Expo phase alone produced 275 lockfile lines. The classifier now reports them in a separate `generated` bucket, counted in neither the JS nor the native totals.

Applied to this study the effect is one line: **LynxJS JS/TS LOC median 393 → 392** (range 335–504 → 335–503). NativeScript is unchanged at 376, and every other published number — output tokens, cost, turns, native LOC, all per-phase figures, all performance and interop results — is bit-identical. Both frameworks' median generated-line count is 0; only two Lynx trials touched a lockfile at all.

The table above carries the corrected figure. It is recorded here rather than silently amended because a published number moved, however slightly.

### 2. Fixed context prefix (MCP schema weight) was not a factor here

`PLAN.md` §4.3 called for measuring MCP tool-schema overhead, since schemas ride in context every turn. The analyzer now records `first_turn_context` per phase — the turn-1 fixed prefix (system prompt + `CLAUDE.md` + all MCP tool schemas), taken from provider-reported usage.

| Phase-1 median | NativeScript | LynxJS | Δ |
|---|---|---|---|
| Fixed context prefix | 34,489 | 34,804 | **+315 (+0.9%)** |

The two arms' fixed prefixes differ by under 1%. **MCP schema weight did not meaningfully influence this study's result** — the 1.9× output-token gap is agent work, not context overhead. This matters mainly as a baseline for the next study: Expo's official MCP exposes 27 tools against NativeScript's docs-only server, so this is the number that comparison gets measured against.

### Pending to close the study

Operator acceptance checklist (SPEC §6) per trial against the archived apps (`results/ns-vs-lynx/<id>/app/`, install via `simctl`) → fills `acceptance` in manifests; any failures get the single standardized remediation round (tokens counted into that trial). Then this report gains the success-rate column and final verdict.
