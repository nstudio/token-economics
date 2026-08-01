# Token Economics Benchmark Plan — NativeScript vs Expo (iOS)

Companion to [`PLAN.md`](./PLAN.md) (NativeScript vs LynxJS, task suite v1.0.0). This document specifies
**task suite v1.1.0** and the second comparison: *NativeScript vs Expo*. Everything not restated here is
inherited verbatim from `PLAN.md`.

**Question:** How many tokens does an AI coding agent consume to build the *same* iOS app — same UI, same two
deep native-platform features — in `ns-benchmark` (NativeScript + Vue 3) vs `expo-benchmark` (Expo SDK 57 +
React Native 0.86)?

---

## 0. Short answer: can this reuse the existing methodology?

**Yes for the machinery, no for two specific things.** The spec, prompts, phase structure, isolation controls,
build-gate protocol, analyzer, and the entire runtime-performance extension transfer 1:1. The design was built
to be framework-parametric and it holds.

Two things do **not** transfer for free:

**(a) The recorded July-25 NativeScript numbers cannot serve as the Expo comparison arm as-is.**
The site's own methodology commits to "the exact model and version… held constant" and "a submission is tied to
a specific date, framework version, and model version. When any of those change, that's a new submission."
`claude --version` is still `2.1.220` today, so drift is *probably* nil — but `claude-sonnet-5` is an alias that
can be repointed server-side without a version bump, and the Expo arm will run days-to-weeks after the NS arm.
Publishing a headline ratio across two non-interleaved measurement windows breaks the study's own rule.
**Recommendation: re-run the NativeScript arm, interleaved with Expo (NS, Expo, NS, Expo…), exactly as with
Lynx.** It costs ~$38 list-price-equivalent and buys three things: a valid headline ratio, a free
**reproducibility datapoint** (two independent NS runs a week apart — precisely the ±5% re-run tolerance the
site's `verified` badge is defined by), and a defensible bridge between the two studies.

**(b) "No plugins for the native features" was never a rule — it was an accident of the frameworks.**
Verified by grep: `harness/spec/SPEC.md`, `harness/prompts/*.md`, `ns-benchmark/CLAUDE.md`, and
`lynx-benchmark/CLAUDE.md` contain no prohibition on adding dependencies. NativeScript reached HealthKit and
Speech directly, so it never wanted a wrapper; LynxJS has no wrapper ecosystem to reach for. Expo is the
opposite case — mature third-party wrappers exist for both features (`@kingstinct/react-native-healthkit`,
`jamsch/expo-speech-recognition`), and an unconstrained agent will install them. Left implicit, the benchmark
would silently switch from measuring *native-access economics* to measuring *wrapper availability*.
**Recommendation: make the rule explicit and symmetric in SPEC v1.1 (§2.2 below), and run the wrapper-allowed
case as a separately reported secondary condition (§5) rather than pretending it away.**

Everything else below is delta from `PLAN.md`.

---

## 1. What transfers unchanged

| Asset | Change needed |
|---|---|
| `SPEC.md` §1, §3, §4, §5, §6 — all screens, labels, acceptance | **none** (byte-identical) |
| `harness/prompts/*.md` | **none** (already placeholder-driven) |
| `harness/run-trial.sh` | one `expo)` case in `configure_framework` |
| `harness/run-main.sh` | framework list `ns lynx` → `ns expo` |
| Isolation controls (scratch `CLAUDE_CONFIG_DIR`, `--strict-mcp-config`, `--dangerously-skip-permissions`, reset-to-tag, interleaving, no-hidden-retries) | **none** |
| `MODEL=claude-sonnet-5`, `MAX_TURNS=160`, n=5 + 1 pilot | **none** (keep pinned to the v1.0 study) |
| Perf extension (`build-release.sh`, `measure.sh`, XCUITest driver, interop bench) | additive only — see §6 |

---

## 2. What must change, and why

### 2.1 Language/UI-layer asymmetry (unavoidable, disclose loudly)

NS and Lynx were both Vue 3. Expo is React 19 / React Native 0.86. Rather than render `SPEC.md` §2's first
bullet per repo — which would have cost byte-identity across arms — v1.1 makes the clause framework-neutral:

> Use the idioms of this project's UI framework; prefer TypeScript wherever the project supports it.

The spec therefore stays **byte-identical across every arm**, and the framework-specific detail lives only in
each repo's `CLAUDE.md`, which was never required to be identical (only structurally so). `harness/sync-spec.sh
--check` enforces the byte-identity.

**This flips the training-data confounder in Expo's favour, hard.** React Native + Expo is the most heavily
represented mobile stack in any model's training corpus — more than NativeScript, far more than Lynx. In the
v1.0 study this confounder favoured NS and was disclosed as such; here it works against the hypothesis. State
that in the hypothesis, not in a footnote. It makes the result *more* interesting either way: if NS still costs
fewer tokens against the most-familiar framework in mobile, the architectural signal is strong; if Expo wins,
the honest read is "ecosystem maturity + familiarity beat interop architecture," which is a real finding.

### 2.2 The no-capability-wrapper rule → SPEC v1.1.0

Added to `SPEC.md` §2 (General rules), identically in **all** repos (`harness/spec/v1.1/SPEC.md`):

> - Implement platform capabilities against the platform's own APIs. Do not add a third-party dependency whose
>   purpose is to wrap the platform capability under test (health store access, speech recognition). Packages
>   shipped as part of the framework's own SDK are permitted. Build tooling, navigation, and UI-layer
>   dependencies are unrestricted.

The complete v1.0 → v1.1 spec diff is two lines (this bullet plus §2.1's neutral idiom clause), publishable
as a single hunk.

Notes on the rule:

- **It is symmetric and binds NativeScript equally** — NS has community health/speech plugins too. That
  symmetry is what makes it fair rather than a handicap on Expo.
- **It is a no-op for the NS arm**, which is exactly why the NS re-run is cheap and why comparing v1.1 NS
  numbers against the published v1.0 NS numbers is a legitimate reproducibility check.
- **For Expo it forces the honest path**: a local Expo module (`npx create-expo-module@latest --local`) →
  `modules/<name>/ios/<Name>Module.swift` + `expo-module.config.json` + `src/*.ts`, autolinked and exposed over
  JSI. Verified: Expo ships no first-party HealthKit or speech-**recognition** module (`expo-speech` is
  text-to-speech), so the rule never collides with an SDK package.
- New baseline tag `benchmark-baseline-v1.1` in each repo; `benchmark-baseline` (v1.0) stays for provenance.
  The v1.0 study's published numbers are **never edited** — v1.1 is a new task suite and a new submission.

### 2.3 MCP parity is the sharpest new problem

NS gets `docs.nativescript.org/mcp` — an HTTP docs server. Expo's official server is
`https://mcp.expo.dev/mcp`: **27 tools**, OAuth-authenticated, including `read_documentation` /
`search_documentation` / `learn` **plus** `add_library` (runs `expo install`), full EAS build+workflow control,
and TestFlight/App Store/Play Store data. There is no documentation-only mode. A separate local tier
(`automation_tap`, `automation_take_screenshot`, `automation_find_view`, `collect_app_logs`,
`expo_router_sitemap`) activates only with the `expo-mcp` package plus `EXPO_UNSTABLE_MCP_SERVER=1`.

**Recommendation:**

1. **Use the official Expo MCP.** Substituting a hand-rolled docs-only server would measure a fictional Expo.
   Real teams get this server; its breadth is genuine ecosystem economics.
2. **Local capabilities stay OFF** — do not add `expo-mcp`, do not set the env var. Simulator tap/screenshot
   would hand Expo a visual verification loop that neither NS nor Lynx had, and the phase gate is a clean build
   on all sides. Record the decision.
3. **Publish MCP tool-schema overhead as a first-class metric.** Implemented: the analyzer now emits
   `first_turn_context` per phase — the turn-1 fixed prefix (system prompt + `CLAUDE.md` + every MCP tool
   schema), read from provider-reported usage. Retro-applied to v1.0 it reads **NS 34,489 vs Lynx 34,804
   median tokens in phase 1 — a ~315-token gap**, i.e. MCP schema weight was *not* a meaningful factor in the
   published study. That is the baseline the Expo arm's 27 schemas get measured against, and it makes the
   metric a real test rather than a rhetorical one.
4. **Count `add_library` calls explicitly** in the tool histogram. The SPEC rule forbids capability wrappers;
   the tool remains available for legitimate installs, and any attempt to reach for a wrapper is data.
5. **Authenticate with a ROBOT token, not interactive OAuth.** The OAuth session expires roughly hourly, which
   no multi-hour run can rely on, and a personal access token is rejected outright — `mcp.expo.dev` answers
   `401 invalid_token: "The MCP server accepts a robot access token here; personal access tokens are not
   supported."` Robot tokens are Expo's CI credential and do not expire on that cadence. The token lives in
   `harness/.env.local` (gitignored, mode 600, written by `harness/set-expo-token.sh` with echo off); the
   committed MCP config carries only the `EXPO_TOKEN` placeholder, so no secret reaches the repo or any trial
   manifest. The docs MCP is re-verified before **every** phase, so a credential dying mid-trial is caught
   rather than silently removing docs from one arm while the trial still reports green.
6. **Record the auth dependency** — the Expo arm requires an Expo account, a robot user, and a network
   round-trip that the NativeScript arm does not.

✅ **Pilot item #1 — RESOLVED (2026-07-31).** The Expo MCP is OAuth-gated; `claude mcp add` alone is not
enough (it writes config, not a token). After `claude mcp add --scope user` + `claude mcp login expo`, a
headless session in the harness's throwaway `CLAUDE_CONFIG_DIR` successfully calls
`mcp__expo__learn` — verified end to end, which is the only test that counts.

**A probe-design trap worth recording.** The first gate asked the model to introspect ("do you have tools whose
names begin with `mcp__expo`?"). After authorization it still answered *absent* while holding working
`mcp__expo__*` tools — a false negative that would have aborted every Expo trial as infra-invalid. The gate
now requires the agent to **actually call** its docs tool and echo the tool name, which both arms pass
(`mcp__expo__learn`, `mcp__nativescript-docs__search_docs`). Models are unreliable narrators of their own
tool inventory; only an invocation is ground truth.

A failed MCP preflight aborts the trial with `outcome: infra-invalid-mcp` — never recorded as data, because
running one arm without its docs server would invalidate the comparison rather than weaken it.

### 2.4 Baseline repo, CNG, and the build gate

- **New repo `expo-benchmark/`**, scaffolded from the framework's own default (`npx create-expo-app@latest`,
  SDK 57 / RN 0.86, New Architecture — mandatory since SDK 55). Keep it **as-scaffolded**, consistent with
  `PLAN.md` §9.5's ruling that template asymmetries are real starting economics. Record verbatim what the
  template ships (Expo Router tabs, demo screens, etc.) in the plan's baseline section, as was done for Lynx.
- **Continuous Native Generation, `ios/` not committed.** This is idiomatic Expo and it is also the interesting
  part: entitlements and `Info.plist` usage strings must go through `app.json` (`ios.entitlements`,
  `ios.infoPlist`) or a config plugin rather than by editing native files, because prebuild regenerates them.
  That declarative-config layer is Expo's analogue to NS's `App_Resources/iOS/` edits (16 native LOC in v1.0) —
  it may well come out *cheaper* than NS, and that should be measurable.
- **Build gate (the phase gate):**
  ```
  npx expo prebuild --platform ios && xcodebuild -workspace ios/*.xcworkspace -scheme <scheme> \
    -configuration Debug -destination 'generic/platform=iOS Simulator' build
  ```
  Same shape as the Lynx gate (JS build + native build). Pin the scheme at baseline.
- `node_modules/`, `ios/`, `Pods/` stay excluded from `git clean` between trials (dependency install cost is
  not what's being measured) — same rule `PLAN.md` §4.3 already applies.

⚠️ **Pilot item #2:** confirm `expo prebuild` without `--clean` is idempotent across repeated agent iterations,
and that a local module in `modules/` survives regeneration (it should — autolinking discovers it; nothing the
agent needs should live in generated `ios/`). If the agent starts hand-editing generated `ios/`, that's a real
finding, not a harness bug — record it.

### 2.5 Bundling `sample.wav`

SPEC §5.1 requires the clip to ship **inside the app bundle** and be loaded from the bundle at runtime.
Under Metro, `require()`d assets are served by the packager in Debug, not embedded — so satisfying §5.1 means
either declaring the file as a resource on the local module's podspec, or shipping a config plugin that copies
it. That is genuine, spec-mandated, measured work — exactly as it was on both v1.0 arms.

⚠️ **Pilot item #3:** verify §5.1 is satisfiable on Expo *at all* within the Debug simulator gate before
committing the baseline. If it turns out to be impossible rather than merely expensive, amend §5.1 in v1.1
symmetrically across all repos (and re-baseline), rather than letting one arm quietly fail the spec.

### 2.6 Analyzer: split native-code from native-config

`analyze.mjs`'s LOC classifier currently splits JS-side vs native-side by extension. Expo breaks that binary:
a config plugin is JavaScript that does native configuration work. **Add a third bucket:**

| Bucket | Files |
|---|---|
| `js` | `.ts .tsx .js .jsx .vue .css` app code |
| `native-code` | `.swift .m .h .kt .java` |
| `native-config` | `.plist .entitlements .xcconfig .podspec`, `project.pbxproj`, `app.json`/`app.config.*` iOS keys, `*.plugin.js` / `plugin/*.js` |

Implemented in `harness/lib/registry.mjs` (`classifyPath`) with the invariant that
`loc_native_added = native-code + native-config`, so the published two-way number never moves — verified
against the pre-refactor output at 900/900 legacy cells identical.

Retro-applied to the v1.0 corpus, the split sharpens the headline considerably:

| Per trial, median | NativeScript | LynxJS |
|---|---|---|
| native-**code** LOC (Swift/ObjC) | **0** | **226** |
| native-**config** LOC (plist/entitlements) | 16 | 18 |
| total native LOC (as published) | 16 | 242 |

"NativeScript wrote zero lines of native-language code while LynxJS wrote 226, with configuration work
essentially equal" is a much more precise claim than the published 16-vs-242, and it isolates the mechanism
exactly. Worth folding into the v1.0 report as a clarifying addendum (new derived view of unchanged evidence,
not a revision of any measured number).

### 2.7 The Expo template ships agent onboarding — normalized away, and disclosed

Discovered while scaffolding (2026-07-31). `npx create-expo-app@latest` (SDK 57 default template) ships, in
addition to app code:

- `AGENTS.md` — "Expo HAS CHANGED. Read the exact versioned docs at docs.expo.dev/versions/v57.0.0/ before
  writing any code."
- `CLAUDE.md` — a single line, `@AGENTS.md`, importing the above.
- `.claude/settings.json` — `{"enabledPlugins": {"expo@claude-plugins-official": true}}`, enabling Expo's
  **official Claude Code plugin**.

Neither the NativeScript nor the LynxJS scaffold ships anything comparable. Left in place, these would breach
controls the v1.0 study is built on: the plugin adds tooling beyond the "exactly one docs MCP and nothing else"
rule (§2.3), and the instruction files break "structurally identical `CLAUDE.md`, same level of help, no
feature hints" (`PLAN.md` §4.1.4).

**All three are removed at the Expo baseline** and the paired `CLAUDE.md` installed in their place. The full
contents are recorded verbatim in `harness/baselines/expo/TEMPLATE-INVENTORY.md`, so the normalization is
auditable rather than invisible.

This is a *real* Expo advantage the benchmark deliberately holds constant, and the report must say so plainly:
a team starting from the stock template gets agent onboarding and a first-party agent plugin for free, and the
measured token numbers give Expo no credit for it. It belongs in the confounders list, not a footnote — and it
is arguably its own follow-up study ("what does shipping agent onboarding buy a framework?"), which this
harness could now run as another study slug.

---

## 3. Hypothesis (pre-registered, before any run)

Expo Modules sit architecturally *between* the two v1.0 arms: reaching a novel platform capability requires
authoring Swift (like Lynx, unlike NS), but the surrounding machinery is far lighter than Sparkling's — a
scaffold command generates the module, autolinking removes the registration step, JSI removes the async-bridge
plumbing, and entitlements are declarative config rather than native-file edits.

**Predictions:**

1. **Phase 1 (UI shell): Expo ≤ NS.** React fluency plus a router-scaffolded template should beat or match NS.
   If Expo loses phase 1, something is wrong with the baseline — investigate before proceeding.
2. **Phase 2 (HealthKit): Expo > NS**, but by a much smaller margin than Lynx's 1.3× — call it 1.2–1.8×.
3. **Phase 3 (Speech) is the headline, as it was in v1.0.** The v1.0 mechanism was *bridging cost recurs per
   native feature; direct-access cost amortizes* — NS's phase 3 fell 71% below its phase 2, Lynx's fell 9%.
   Prediction: **Expo's phase 3 partially amortizes** (module scaffold pattern is now known, but a second Swift
   module must still be written) — expect a 25–50% phase-2→3 drop, between NS's 71% and Lynx's 9%.
4. **Native-code LOC: NS ~0–5, Expo ~80–200, Lynx ~240** (v1.0 measured). Native-config LOC may favour Expo
   over NS.

**Falsifier, stated in advance:** if Expo's phase 3 drops ~70% like NS's did, the "authoring cost recurs per
feature" thesis does not hold for Expo Modules, and the study should say so plainly in the headline.

---

## 4. Trial matrix (primary study)

| Arm | Repo | Trials | Docs MCP | Rule |
|---|---|---|---|---|
| NativeScript | `ns-benchmark` @ `benchmark-baseline-v1.1` | 1 pilot + 5 | `docs.nativescript.org/mcp` | v1.1 no-wrapper |
| Expo | `expo-benchmark` @ `benchmark-baseline-v1.1` | 1 pilot + 5 | `mcp.expo.dev/mcp` (remote tier only) | v1.1 no-wrapper |

Interleaved `ns, expo, ns, expo…`, strictly sequential, one machine, same Xcode, `claude-sonnet-5`,
`MAX_TURNS=160`. Pilot trials reported but excluded from medians (per v1.0 precedent).

---

## 5. Secondary condition: the wrapper-allowed arm (recommended)

The predictable objection to the primary study is "nobody hand-writes a HealthKit module in Expo — you install
a package." That objection is correct about practice and irrelevant to the architectural question, so answer it
with data instead of argument — the same posture the v1.0 report took toward "but Lynx performs better."

- **Expo-unconstrained, n=3**, identical harness, SPEC v1.1 minus the no-wrapper bullet (call it profile
  `v1.1-open`). Expect a very large drop; that delta *is* the quantified value of the wrapper ecosystem.
- **NativeScript-unconstrained, n=3** for symmetry. If no comparable NS wrapper exists at usable quality, do
  not fake it — record availability as the finding and label the Expo-open arm explicitly as
  "Expo best case vs NS measured case, not apples-to-apples."
- Report as a clearly separated condition. **Never** merge into the primary medians.

---

## 6. Runtime performance extension (inherits `PLAN.md` §8)

No new agent trials; measure the artifacts. All of §8 applies unchanged. Three additive notes:

- **Engine table becomes three-way.** The interop bench's scenario code and `check` values are already fixed
  and cross-verified, so an Expo/Hermes column drops straight into the published V8-vs-PrimJS table.
  `js_compute` on Hermes vs V8 (57 ms) vs PrimJS (271 ms) is a genuinely new number.
- **The interop headline is `prim_latency`.** v1.0 measured NS direct binding at ~1 µs/call vs Lynx's async
  bridge at ~130 µs/call. Expo Modules over JSI are *synchronous* — the prediction is single-digit µs, i.e.
  near NS and two orders off Lynx. If that holds, "bridge tax" is a Lynx-architecture property, not a
  wrapped-module property, and the report should say so.
- ⚠️ **Pilot item #4:** the XCUITest driver taps SPEC-pinned label strings via the accessibility tree. RN's
  `Text`/`Pressable` expose labels differently than NativeScript and Lynx views. Smoke-test the existing driver
  against the pilot Expo build before the main run; if it needs an Expo-specific query path, add it to the
  driver *before* any measured app exists, never after (adjusting a driver to fit built apps is p-hacking).

---

## 7. Website work (`agent-tokenomics`)

The site is currently single-study by construction, so this is real work, not a data-file drop:

- `src/lib/comparisons/study-data.ts` is one module with `FrameworkKey = 'nativescript' | 'lynxjs'` and literal
  `nativescript:` / `lynxjs:` keys throughout `phases`, `trialTotals`, `rawPhaseRows`, `totals`, `perf`,
  `interop`. It is imported by six routes/components (`routes/index.tsx`, `comparisons/index.tsx`,
  `$slug.tsx`, `$slug_.methodology.tsx`, `$slug_.performance.tsx`, `$slug_.reproduce.tsx`, plus
  `ResultsTable`, `GroupedTokenBars`, `CompositionBars`, `TrialRanges`).
  → **Refactor to per-comparison study data** keyed by generic framework id, attached to `ComparisonMeta`, with
  charts taking the study as a prop.
- `routes/index.tsx` and `comparisons/index.tsx` hard-code `comparisons[0]` / `totals.nativescript` /
  `totals.lynxjs` for the homepage headline → generalize to "featured comparison" + a real list.
- Add `src/lib/comparisons/nativescript-vs-expo.ts` (`ComparisonMeta`) and register it in `index.ts`.
- `routes/methodology.tsx` gains a note on task-suite versioning and the v1.1 no-wrapper rule.
- Do this refactor **before** the numbers land, so publishing is a data commit.

---

## 8. Budget & schedule

From v1.0 measured cost (list-price-equivalent under subscription auth): NS **$7.52/trial**, Lynx
$18.29/trial. Expo predicted between them, ~$9–14.

| Item | Trials | Est. |
|---|---|---|
| Pilot (NS + Expo) | 2 | ~$22 |
| Main run, primary | 10 | ~$38 NS + ~$55 Expo ≈ **$95** |
| Secondary open arms (optional) | 6 | ~$35 |
| **Agent total** | 18 | **~$150** |

Wall clock: ~22 min/NS trial, ~30–40 min/Expo trial → **7–10 h sequential** for the main run, plus perf suite
(~3 h) and baseline/pilot day. Under subscription auth these share one usage window — run sequentially, never
concurrently, and mark any usage-limit death `infra-invalid` rather than as a framework failure (v1.0 protocol).

---

## 9. Execution order

| Step | What | Output |
|---|---|---|
| 2 | **✅ done** — harness generalized to a framework/study registry (`harness/frameworks/`, `harness/studies/`, `lib/registry.mjs`, `lib/common.sh`); `expo.json` + `mcp/expo.mcp.json` added; three-bucket LOC classifier + `first_turn_context` in `analyze.mjs`; perf suite study-aware; `sync-spec.sh` and `manifest.mjs` added; v1.0 results namespaced under `results/ns-vs-lynx/` with every published number re-verified | harness v1.1 |
| 1 | **✅ done** — SPEC v1.1 authored (`harness/spec/v1.1/`, two-line diff vs v1.0, assets checksum-identical); Expo `CLAUDE.md` written to `harness/baselines/expo/` structurally identical to the NS one | SPEC v1.1.0 |
| 0 | **✅ done 2026-07-31** — `expo-benchmark` scaffolded from the default `create-expo-app` template (SDK 57.0.9 / RN 0.86.2 / React 19.2.3 / Expo Router); `app.json` pinned to `name: ExpoBenchmark` + explicit bundle id, so prebuild emits exactly `ios/ExpoBenchmark.xcworkspace`; template agent files removed per §2.7; paired `CLAUDE.md` and spec v1.1 installed; **§2.4 build gate green** (`** BUILD SUCCEEDED **`) | green blank repo |
| 3 | **✅ done 2026-07-31** — both repos build green and are tagged `benchmark-baseline-v1.1` (ns `b51dc82` on branch `baseline-v1.1`, expo `e055a19` on `main`); `./sync-spec.sh ns-vs-expo --check` passes | tagged baselines |
| 4 | **BLOCKED on pilot item #1** — Expo MCP needs one interactive OAuth (§2.3); measured trials cannot start until the probe returns `EXPO_MCP_PRESENT`. Then: pilot 1 NS + 1 Expo, clearing items #2–#4 (prebuild idempotency, §5.1 bundling feasibility, XCUITest label matching). Amend spec/harness here — never after | calibrated harness, frozen spec |
| 5 | Main run: 5×2 interleaved (`run-main.sh 5`) | `results/` |
| 6 | Acceptance checklist per trial (+ ≤1 remediation round each, tokens counted) | success rates |
| 7 | Perf extension: Release rebuilds, size/launch/memory, XCUITest latency, interop bench (three-engine table) | `results/perf/` |
| 8 | Analysis → `results/REPORT-EXPO.md`; site refactor + publish | the answer |
| 9 | *(optional)* Secondary open arms, n=3 each | wrapper-ecosystem delta |

---

## 10. Decisions needed

1. **Re-run the NS arm, or reuse July-25 data?** → Recommend re-run (§0a). Reuse is defensible only if you
   accept a cross-window comparison and label it as such.
2. **Ship the secondary wrapper-allowed arm?** → Recommend yes, at least for Expo (§5). It costs ~$35 and
   pre-empts the study's most obvious critique.
3. **Scope: two-way NS-vs-Expo, or three-way including Lynx?** → Recommend **two-way**. A three-way headline
   requires re-running Lynx under v1.1 as well (+~$90, +6 h) and the site is not yet multi-study. Keep v1.0
   frozen as published and relate the studies through the reproduced NS arm.

---

## 11. Confounders to disclose (delta from `PLAN.md` §6)

1. **Training-data familiarity now favours Expo**, strongly — inverted from v1.0. Lead with it.
2. **UI layer differs** (React vs Vue), unavoidable; phase 1 is the read on how much that alone is worth.
3. **MCP asymmetry is structural**: 27 tools with build/store/install reach vs one docs server. Measured as
   schema overhead and tool-mix, not eliminated.
4. **CNG vs committed native project**: Expo regenerates `ios/`, NS commits `App_Resources/`. Different
   native-config economics by design; the three-bucket LOC split is what makes it legible.
5. **The no-wrapper rule is a constraint on practice.** It isolates interop architecture at the cost of
   realism — which is exactly what §5's open arm exists to quantify.
6. **Alpha toolchain on the NS side** (9.1-alpha) vs a stable Expo SDK 57 release — carried over from v1.0.
7. **Expo ships agent onboarding that this benchmark removes** (§2.7): `AGENTS.md`, a `CLAUDE.md`, and an
   enabled official Claude Code plugin come with the stock template. Normalizing them away is required to hold
   the study's controls, but it means the measured numbers understate what a real Expo team gets on day one.
8. **Stochasticity**: n=5, medians, full raw disclosure — unchanged.

---

## 12. Fairness audit of the NativeScript arm (2026-08-01, after n=5)

Asked directly: is NativeScript being properly utilised, or is Expo gaining from a
setup defect? Six checks over the archived transcripts.

| Check | Finding |
|---|---|
| `CLAUDE.md` parity | Structurally identical — same five sections, 187 vs 239 words |
| Tool access | `idb` installed and used by both arms (NS 211 calls, Expo 50) |
| Tool-call failure rate | NS **1.2%**, Expo 1.8% — NS is not fighting errors |
| Dev loop | NS's HMR loop available and used; agents mostly chose full rebuilds |
| Prompts / model / turn cap / spec | Byte-identical; conditions verified uniform across all trials |
| Docs MCP health | 86 NS calls, 2 near-empty — the server works |

**Conclusion: the NativeScript arm is not handicapped.** Its higher token use traces
to three real behaviours, none of them a setup defect:

1. **Its docs server returns smaller chunks.** NativeScript's `search_docs` averages
   4,958 chars/call; Expo's `read_documentation` returns 16,752 — whole pages. NS made
   86 calls to Expo's 10, pulling ~2.5× more total documentation to get there. Docs
   quality is explicitly within scope (`PLAN.md` §6.2), not noise to remove.
2. **Much heavier interactive UI verification** — `idb` 211 vs 50, `simctl` 86 vs 15.
3. **Different discovery targets** — NS read its own app source 77× and
   `@nativescript/types` iOS declarations 14×, hunting API signatures; Expo read its
   own generated module scaffold 59×.

**The mechanism in one line:** NativeScript discovers; Expo follows a scaffold. Expo
wrote 1.7× more JavaScript *and* 213 lines of Swift while spending fewer tokens,
because `create-expo-module` hands it a known-good shape. NativeScript's "call any
API directly" freedom means working out *which* call, every time.

**Superseded by §13.** This section originally logged the 9.06-vs-3.10 bash-calls-per-edit
gap as an open question about agent choice, and glossed it as "NativeScript agents verified
more; Expo agents trusted the build." That was a rationalisation of a number rather than an
explanation of it. Investigated properly (§13), verification effort turns out to correlate
with token cost at **r = 0.90 within each arm** — which makes it a confound on the headline
comparison, not a characteristic of either framework.

---

## 13. Confound: interactive UI verification is entangled with token cost (2026-08-01)

**This is the most serious limitation in the study and it constrains the headline claim.**

Both frameworks' agents had the same tools, including `idb` (installed and working)
for driving the simulator UI. How much each agent chose to use it correlates with its
total token cost at **r = 0.90 — within NativeScript, within Expo, and pooled across
all ten trials.**

| | `idb ui tap` calls per trial | Trials with zero |
|---|---|---|
| NativeScript | 21, 37, 37, 37, 23 | **none** |
| Expo | 6, 0, 0, 21, 14 | **two** |

Expo's three cheapest trials (58.5k, 59.3k, 63.8k output) tapped 0, 0, and 6 times.
Its two most expensive (94.2k, 72.1k) tapped 21 and 14, landing inside NativeScript's
range. NativeScript never skipped verification in any trial.

### What was ruled out

An architectural explanation was hypothesised and **rejected**: NativeScript resolves
native calls at runtime via reflection, so a wrong API name compiles cleanly and would
only fail when run — which would *force* the agent to drive the app, where Expo's
compiled Swift module is checked by `xcodebuild`. Searching every transcript for
genuine runtime-failure signatures (`unrecognized selector`, `NSInvalidArgumentException`,
`JS ERROR`, `SIGABRT`, `Terminating app due to`) found **zero occurrences on both arms**.
The hypothesis is not supported by this data.

Also ruled out as causes: `CLAUDE.md` "Definition of done" wording (byte-identical
across arms), tool availability (both had `idb`), and tool-failure rates (NS 1.2%,
Expo 1.8%).

### What this means for the result

The measured token gap is **substantially confounded with verification effort**, and
that effort varies within Expo about as much as it differs between the two frameworks.
"Expo costs 0.67× the tokens" therefore cannot be attributed to interop architecture
on this evidence. It was already directional only (p = 0.056, overlapping ranges); this
confound weakens it further.

Stated plainly: the study measures *what these agents did*, and a large share of what
they did was decide how much to verify.

### Why acceptance testing becomes load-bearing

If the trials that skipped verification produced apps that fail the SPEC §6 checklist —
permission flows, streaming partial results, deny paths — then their lower token counts
represent **unfinished work rather than efficiency**, and the comparison may inverse.

`main-expo-2` and `main-expo-3` are the two cheapest trials in the study and the only
two that never drove the UI. They are the highest-priority acceptance candidates.

### Follow-up worth running (not a correction to this study)

A condition with UI-automation tools withheld from both arms would isolate
build-verified implementation cost from interactive-verification cost. That is a
separate study slug, which this harness now supports as data.

---

## 14. Corrected analysis: the raw token comparison was an artifact (2026-08-01)

**This supersedes every earlier headline in this document, including §3's predictions
and the n=5 figures reported during the run.**

### The finding

Controlling for how much interactive UI verification each agent performed reverses the
result. At every matched level of verification effort, **NativeScript uses fewer tokens
than Expo**:

| Verification band | NativeScript median | Expo median | Cheaper |
|---|---|---|---|
| 0–7 `idb ui tap` calls | **57,160** | 63,838 | NativeScript |
| 8–25 taps | **78,339** | 87,832 | NativeScript |
| 26+ taps | **110,390** | 111,471 | NativeScript |

The banded comparison involves no modelling — it is the trials sorted by verification
effort. A regression over the same 15 trials agrees:

| Model | Framework coefficient (NS vs Expo) | t | R² |
|---|---|---|---|
| `tokens ~ framework` | +9,598 | 0.93, n.s. | **0.06** |
| `tokens ~ taps + framework` | **−11,737** | **−2.37, p<0.05** | **0.86** |

Framework alone explains **6%** of variance in token cost. Adding verification effort
explains **86%**, at ~1,500 tokens per UI tap (t = 8.16) — and the framework coefficient
*changes sign*.

Two trials from the n=6–8 batch made this unmissable: `main-ns-7` performed 5 taps and
became the cheapest NativeScript trial in the study (57,160); `main-expo-8` performed 37
taps and became the most expensive Expo trial (111,471). Neither is explicable by
framework; both are explicable by verification effort.

### What was previously reported, and why it was wrong

At n=5 this document and the run commentary reported "Expo costs 0.67× the tokens" as
the headline, with the caveat that it was directional (p = 0.056). That framing was
wrong in substance, not just in confidence: the gap was **not a framework effect at
all**. It measured NativeScript's agents choosing to drive the simulator 20–37 times per
trial while Expo's agents did so 0–37 times with far more scatter.

The error was compounded by an unfounded gloss — "NativeScript agents verified more;
Expo agents trusted the build" — which explained the number by restating it. The
confound was found only when that sentence was challenged directly.

### What the study can claim

1. **Verification behaviour dominates measured agent cost** (R² = 0.86), far exceeding
   framework choice (R² = 0.06). For anyone budgeting agent spend, *how thoroughly the
   agent is told to verify* matters more than which of these two frameworks is used.
2. **At matched verification effort, NativeScript is the more token-efficient of the
   two**, consistently across all three bands.
3. The per-tap cost is substantial and measurable: **~1,500 output tokens per UI
   interaction**.

### What remains unexplained

Why NativeScript's agents verified more consistently (20–37 taps in six of seven trials)
than Expo's (0–37, high scatter) is **not established**. An architectural hypothesis —
that NativeScript's runtime binding lets bad native calls survive the build, forcing the
agent to run the app — was tested against every transcript and **rejected**: zero genuine
runtime-failure signatures on either arm. Prompt-response variance and some unmeasured
property of the frameworks both remain live, and this data cannot separate them.

### Consequence for design

A future study should either **hold verification effort constant** (withhold UI-automation
tools from both arms, measuring build-verified implementation cost) or **treat it as a
declared independent variable** rather than letting agents choose it freely. Letting it
float means the headline measures agent behaviour, not framework economics.

The `results/ns-vs-expo/REPORT.md` write-up must lead with this and must not publish a
raw token ratio as a framework comparison.

---

## 15. Does the confound invalidate the published v1.0 study? No. (2026-08-01)

§14 showed that free-choice verification effort swamped the framework signal in this
study. The obvious next question is whether the same flaw undermines the published
NativeScript-vs-LynxJS result. It does not, and the reason is instructive.

| | v1.0 — NS vs LynxJS | v1.1 — NS vs Expo |
|---|---|---|
| UI-verification calls, median | NS 31 · Lynx 35 — **comparable** | NS 26 · Expo 7.5 — **3.5× apart** |
| r(verification, tokens), pooled | 0.47 | **0.89** |
| Per-trial range overlap | **none** | substantial |
| Framework gap | ~58,000 tokens (1.9×) | ~10,000 tokens |

In v1.0 both arms verified at similar rates, so verification effort largely **cancels**
between them. The 4-call median difference is worth roughly 6,000 tokens at the measured
~1,500/call — under 10% of a 58,000-token gap that already had non-overlapping ranges.
**The published 1.9× result stands.**

In v1.1 the arms differed 3.5× in verification while the framework gap was only ~10,000
tokens — small enough for verification to dominate it completely.

### The actual lesson

The free-verification design is not universally broken; it has **no resolving power when
the frameworks are closely matched**. v1.0 survived because LynxJS's disadvantage was
overwhelming enough to swamp the noise. NativeScript vs Expo is a close comparison, and
the design could not resolve it.

Two consequences for future studies:

1. **Report the verification-effort asymmetry as a standard diagnostic**, alongside the
   token medians, in every study. If the arms differ materially, the headline ratio is
   not a framework result. This is cheap: `harness/analyze-confound.mjs` computes it from
   archived transcripts with no new trials.
2. **When a pilot suggests a close comparison, pin verification effort** — an identical
   instruction in both arms' prompts — rather than letting agents choose. That is a new
   spec version and a new study slug, not an amendment to a published one.
