# Results — Token Economics: NativeScript vs Expo (iOS)

Methods: [`../../PLAN-EXPO.md`](../../PLAN-EXPO.md) (deltas) and [`../../PLAN.md`](../../PLAN.md) (base protocol).
Runner details: [`../../harness/README.md`](../../harness/README.md).

**Status (2026-08-01):** complete. Two studies, 26 measured trials, 78/78 phases build-green.
Every app rebuilt in Release, functionally verified, and performance-profiled.


---

## Correction (2026-08-02) — app size was measured on simulator builds

**What was wrong.** App size came from the `Release-iphonesimulator` `.app` directory measured with
`du`. That bundle carries an x86_64 slice that never ships and full symbol tables. NativeScript's
published 93.3 MB was 67.2 MB of `NativeScript.framework`, whose binary was a 59 MB fat Mach-O
(30 MB x86_64 + 29 MB arm64) with 49,215 symbols and a debug map. It is not an app size.

**Why the ratio was wrong too.** Both arms were inflated, but not by the same proportion —
NativeScript shed 45% on re-measurement, Expo 50% — so the published gap was also off.

**What was done.** Every trial tree was re-archived with `harness/perf/build-device.sh`:
`xcodebuild archive`, `-destination generic/platform=iOS`, signing disabled. `archive` rather than
`build`, because only the archive action runs the strip and postprocessing an App Store build gets.

| Figure | As published | Corrected |
|---|---|---|
| NativeScript bundle | 93.3 MB | **51.1 MB** (n=8, no variation) |
| Expo bundle | 57.1 MB | **28.7 MB** (n=8, 27.4–28.7) |
| NativeScript executable | 23.4 MB | **11.8 MB** |
| Expo executable | 5.3 MB | **1.3 MB** |
| Headline gap | −39% | **−44%** |

Figures remain uncompressed and un-thinned, so they are upper bounds on download size. The direction
of the finding is unchanged. Token results, memory, launch, and CPU are unaffected — those were
always simulator measurements and remain so. Per-trial data: `perf/device/*.json`.

---

## The headline

**At matched verification effort, NativeScript and Expo cost statistically indistinguishable agent
tokens to build the same iOS app.** Mann-Whitney U = 13 of 25, exact two-tailed **p = 1.00** — the
expected value under a true null is 12.5.

The uncontrolled study appeared to show Expo 0.82× cheaper. That was not a framework effect. It was
**how much each agent chose to test its own work**, which explains **84%** of token variance against
framework choice's **6%**.

> **The most useful number in this study is not a framework ratio. It is ~1,160 output tokens per
> interactive UI verification step** — and the finding that verification effort, not framework choice,
> dominates what an agent costs.

---

## Two studies

| | Free-choice | Build-verified |
|---|---|---|
| Slug | `ns-vs-expo` | `ns-vs-expo-buildonly` |
| Verification | agent's discretion | **forbidden, both arms** |
| Trials | 8 + 8 | 5 + 5 |
| Compliance | — | **10/10 made zero UI calls** |

Both use spec v1.1.0, the same baselines, `claude-sonnet-5`, and a 160-turn cap. The build-verified
study adds one line to both arms' prompts: *do not launch, install, or drive the app on a simulator.*
Compliance is not assumed — it is counted in the transcripts.

---

## 1. Token cost

### Free-choice (n=8 per arm)

| Per trial | NativeScript | Expo |
|---|---|---|
| Output tokens | **83.4k** (57.2–111.7k) | **68.5k** (58.5–111.5k) |
| Turns | 238 | 159 |
| Cache-read | 18.0M | 9.1M |
| Docs lookups | 15.5 | 2 |
| JS/TS LOC | 313 | **551** |
| Native-language LOC | **0** | **209** |
| Native-config LOC | 14 | 62 |

Ranges overlap heavily. **This ratio is not a framework result** — see §2.

### Build-verified (n=5 per arm, verification pinned off)

| Per trial | NativeScript | Expo |
|---|---|---|
| Output tokens | **66.9k** (46.1–75.3k) | **57.9k** (50.8–78.8k) |
| Turns | 142 | 130 |
| Native-language LOC | **0** | **189** |

**Mann-Whitney U = 13/25, p = 1.00.** No detectable difference.

### Cost

Free-choice: NativeScript **$8.45** (n=5/8), Expo **$5.18** (n=6/8). Build-verified: **$4.19** vs
**$3.70** (n=5/5). Cost coverage is incomplete because two Expo phase-1 sessions returned headless
summaries that under-reported usage by >90% against their transcripts; cost exists only in the summary,
so it is withheld for those phases rather than published as a plausible-looking wrong number. Token
counts are transcript-derived and exact on both arms.

---

## 2. Why the raw ratio is not a framework result

Agents chose how much to drive the simulator UI, and that choice cost tokens.

| | UI-verification calls per trial |
|---|---|
| NativeScript | 21, 37, 37, 37, 23, 20, 5, 18 — **never zero** |
| Expo | 6, 0, 0, 21, 14, 5, 9, 37 — **zero twice** |

Pooled correlation between verification calls and total tokens: **r = 0.89**.

| Model | Framework coefficient | R² |
|---|---|---|
| `tokens ~ framework` | +9,598 (t=0.93, n.s.) | **0.06** |
| `tokens ~ verification + framework` | **sign flips** (t≈2.1, borderline) | **0.84** |

Framework alone explains 6% of variance. Adding verification explains 84%, at **~1,160 tokens per UI
call** (t = 8.04). Reproduce with `node harness/analyze-confound.mjs ns-vs-expo`.

**An architectural explanation was tested and rejected.** NativeScript resolves native calls at runtime,
so bad calls could survive the build and force the agent to run the app. Searching every transcript for
genuine runtime-failure signatures (`unrecognized selector`, `NSInvalidArgumentException`, `JS ERROR`,
`SIGABRT`) found **zero on both arms**. Why NativeScript's agents verified more consistently remains
unexplained.

**One real workflow asymmetry did emerge:** verifying an Expo app requires starting Metro first, a step
NativeScript does not need. Free-choice Expo agents attempted it 21 times.

### Does this invalidate the published LynxJS study? No.

| | v1.0 (NS vs LynxJS) | v1.1 (NS vs Expo) |
|---|---|---|
| Verification asymmetry | 0.9× — comparable | **2.3×** |
| r(verification, tokens) | 0.47 | **0.89** |
| Framework alone | R² = **0.87**, t = 7.35 | R² = 0.06, n.s. |
| Range overlap | **none** | substantial |

In v1.0 both arms verified at similar rates, so the effect cancels; framework alone explains 87% and
adding verification leaves it significant. **The published 1.9× result stands.** The free-choice design
loses resolving power only when the frameworks are closely matched — which NativeScript and Expo are,
and LynxJS was not.

---

## 3. Correctness

Every Release app driven through the SPEC flows by the XCUITest driver — navigation, HealthKit
authorization, 7-day list, log→refresh.

| | NativeScript | Expo |
|---|---|---|
| Free-choice | **8/8** | **8/8** |
| Build-verified | **5/5** | **4/5** |

**The one failure is the study's sharpest finding.** `ns-vs-expo-buildonly/main-expo-1` returns
`health_granted: false` deterministically across three re-runs while its nine siblings pass under the
same driver. It compiles cleanly and its Swift status mapping reads correctly, but authorization never
resolves at runtime — a defect no compiler catches, in the one condition where the agent was forbidden
from ever launching its own app.

So: interactive verification cost ~1,160 tokens per call and caught a defect the build gate could not.
**n=1 failure** — the existence proof is solid, the rate estimate is not.

**Speech is simulator-blocked on both arms** (`Failed to initialize recognizer` — `SFSpeechRecognizer`
rides Siri infrastructure the Simulator lacks). All 26 apps surfaced it in the status line per spec
rather than crashing. Identical to v1.0; excluded from verdicts, needs a device.

---

## 4. Runtime performance (Release, one fixed simulator)

| Metric | NativeScript | Expo | Δ |
|---|---|---|---|
| App bundle on disk (arm64 device archive) | 51.1 MB | **28.7 MB** | **−44%** |
| Main executable | 11.8 MB | 1.3 MB | −89% |
| Cold launch → active | 302 ms | 301 ms | **tie** |
| Launch settle | 1,447 ms | 1,547 ms | +7% |
| Idle memory (RSS) | **216 MB** | 228 MB | +6% |
| Idle footprint | 40 MB | **34 MB** | −15% |
| Idle CPU | 0.0% | 0.0% | tie |

**NativeScript is the heavier option here.** Memory is mixed — RSS favours NativeScript, physical
footprint favours Expo — and neither gap is decisive. (Size rows re-measured 2026-08-02 on device
archives; see the Correction at the top. v1.0's size finding was corrected in the same pass and no
longer shows NativeScript as the lighter framework there either.)

### Tap-to-result latency

| Path | NativeScript | Expo | Read |
|---|---|---|---|
| Nav → Health rendered | 2,220 ms | 1,998 ms | Expo 10% faster |
| **7-day HealthKit query → rows** | **1,069 ms** | **1,075 ms** | **tie** |
| Log 500 → list refreshed | 513 ms (369–643) | 386 ms (355–403) | Expo 25% faster |
| Nav → Transcribe rendered | 2,168 ms | 2,205 ms | tie |

The heavy read path is a dead tie across **three frameworks and two studies**: NativeScript 1,059 →
1,069 ms, LynxJS 1,085 ms, Expo 1,075 ms — all within 2.5%. The OS API dominates; framework choice is
invisible here.

The log→refresh gap echoes v1.0 exactly, including the shape: NativeScript's range is wide (369–643)
where the comparand's is tight, tracing to differing agent refresh strategies. Partly implementation
choice, not purely framework ceiling.

### Cross-study replication

NativeScript, measured weeks apart in an independent study, reproduces v1.0 **within 1% on every
metric**: RSS ~215 MB, HealthKit query ~1,060 ms, and — after the 2026-08-02 size correction — a
device-archive bundle of 51.1 MB on both, identical to the byte across all 8 archives. This is the
strongest validity check available here.

**Not measured:** JS↔native interop microbenchmarks. v1.0's suite requires a hand-written bench app plus
an equivalent native fixture per framework; Expo has none. Building one would add Hermes to the
V8-vs-PrimJS engine table and test whether Expo's synchronous JSI modules land near NativeScript's ~1 µs
direct binding or LynxJS's ~130 µs async bridge. Worth doing; not done here, and not claimed.

---

## 5. What each framework actually did

Both arms respected the v1.1 no-capability-wrapper rule in every trial — no third-party HealthKit or
speech dependency was installed.

- **NativeScript** wrote **zero lines of native-language code** across both features. All native-side
  work was Info.plist and entitlement configuration (14 lines), with feature logic in TypeScript.
- **Expo** authored **~209 lines of Swift** across two local Expo modules, plus 62 lines of native
  configuration, plus 1.7× more JavaScript — at statistically indistinguishable token cost.

Two architectures reaching the same platform capabilities by completely different routes, for the same
agent spend.

---

## 6. Limits and disclosures

1. **Verification effort was free-floating in the primary study.** That is why the build-verified
   condition exists, and why the headline comes from it.
2. **n=5 in the controlled study.** p=1.00 is a clean null, but absence of evidence at this n is not
   strong evidence of absence for small effects.
3. **The correctness finding rests on one failure.** Existence proof, not a rate.
4. **Training-data asymmetry favours Expo**, strongly — React Native is the most-represented mobile
   stack in any model's corpus. That it did not produce a measurable token advantage is itself notable.
5. **UI-layer differs** (React vs Vue) — unavoidable, disclosed.
6. **Expo's template ships agent onboarding** (`AGENTS.md`, `CLAUDE.md`, an enabled Claude Code plugin)
   that this benchmark removes for parity. Real teams get it free; these numbers give Expo no credit.
7. **The Expo baseline was changed after the pilot** from the default template to `blank-typescript`,
   because the default's ~750 lines of demo content made phase 1 measure deletion rather than
   construction. `pilot-expo-1` is retained and flagged `superseded`.
8. **Driver coverage:** back-navigation is not a spec-pinned label. Three Expo apps use a `‹ Home`
   control the driver cannot match, so their Transcribe metrics are absent — coverage, not defect.
9. **Simulator on one Mac.** Absolute numbers are not device numbers; only comparative readings transfer.
   Launch times drifted ~16 ms between measurement sessions, affecting both arms equally — compare
   within a session, never across.
10. **Three infra-invalid events**, each caught before spending measured tokens and preserved in the
    record: Expo MCP OAuth expiry, Claude subscription auth expiry, and a transient
    `docs.nativescript.org/mcp` outage.

---

## 7. Methodology note: silent failures dominate

Six defects surfaced during this study, **every one of which produced plausible numbers with no error
raised**:

| Defect | Would have caused |
|---|---|
| Lockfiles counted as authored code | Expo's JS LOC inflated ~60% |
| Headless summary trusted over transcript | a phase priced at $1.43 for 14,937 tokens of work |
| Trial branches not study-scoped | Release rebuilds measuring the wrong study's code |
| Hardcoded trial lists (3 scripts) | perf silently covering 5 of 8 rounds |
| Acceptance run on RN Debug builds | 13 meaningless verdicts against apps that never loaded |
| "Not reached" scored as "failed" | publishing *Expo fails acceptance 3× more often* — false |

The last two are the instructive pair. Both attributed a **harness limitation to the artifact**. One was
caught only because an operator looked at the simulator screen and saw a red error dialog where an app
should have been.

**In a pipeline this long, "it ran and produced numbers" is nearly worthless as evidence that it ran
correctly.** Every number here that matters was checked against the artifact it claims to describe.

---

## Reproduce

```sh
cd harness
node analyze.mjs ns-vs-expo                 # token results
node analyze.mjs ns-vs-expo-buildonly       # controlled condition
node analyze-confound.mjs ns-vs-expo        # the verification confound
node manifest.mjs ns-vs-expo --check        # verify archived evidence

cd perf
node analyze-acceptance.mjs ns-vs-expo      # functional verdicts
node analyze-perf.mjs ns-vs-expo            # size / launch / memory
node analyze-interactions.mjs ns-vs-expo    # tap-to-result latency
```
