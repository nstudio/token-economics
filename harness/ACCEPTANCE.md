# Operator acceptance checklist (SPEC.md §6)

The build gate proves an app **compiles**. This proves it **works**. Until it runs,
every trial's success is "build-green," which is not the same claim — and the
report cannot publish a success rate without it.

Budget ~5 minutes per app.

## Mechanics

```sh
cd harness
./acceptance.sh ns-vs-expo list                      # what's pending
./acceptance.sh ns-vs-expo install main-ns-1         # clean install + launch
# …run the checklist below…
./acceptance.sh ns-vs-expo pass main-ns-1
./acceptance.sh ns-vs-expo fail main-ns-1 "partial results never stream"
```

`install` uninstalls any previous copy first. That matters: the deny-path checks
are meaningless against an app that has already been granted permission.

## The checklist

Run these in order. The app must **never crash**, including on denial.

### 1. Shell and navigation
- [ ] Home shows title `Native Bench` and subtitle `Token economics benchmark`
- [ ] Buttons `Health` and `Transcribe` are both present
- [ ] Each opens its screen, and each screen can get back to Home

### 2. Health — deny path first (order matters)
Do this **before** granting, since permission state is one-way per install.
- [ ] Status reads `Health access: not requested`
- [ ] Tap `Request Access` → **deny** in the sheet
- [ ] Status becomes `Health access: denied`
- [ ] `Log 500 Steps` stays disabled; list area shows `Health access needed`
- [ ] No crash

> HealthKit denial is sticky per install. Re-run `install` to reset before the
> grant path — that is why this ordering exists.

### 3. Health — grant path (after a fresh `install`)
- [ ] `Request Access` → **allow** all
- [ ] Status becomes `Health access: granted`
- [ ] Tap `Log 500 Steps` twice
- [ ] Today's row reads at least `1,000 steps (today)` and is visually emphasized
- [ ] Exactly 7 rows, most recent first, format `Fri Jul 25 — 1,000 steps`
- [ ] Force-quit and relaunch → the data is still there

### 4. Transcribe — deny path (fresh `install`)
- [ ] Status reads `Speech access: not requested`
- [ ] `Request Access` → **deny**
- [ ] Status becomes `Speech access: denied`; `Transcribe Sample` stays disabled
- [ ] No crash

### 5. Transcribe — grant path (fresh `install`)
- [ ] `Request Access` → **allow**; status becomes `Speech access: granted`
- [ ] Tap `Transcribe Sample`
- [ ] Status shows `Transcribing…` and the button disables
- [ ] Transcript text **visibly updates more than once** (partial streaming — a
      single final dump is a fail)
- [ ] Final transcript ≥90% word overlap with `spec-assets/reference-transcript.txt`
      (case- and punctuation-insensitive)
- [ ] A line `Completed in N.N s` appears beneath it

> **Known environment limit:** `SFSpeechRecognizer`'s server path rides Siri
> infrastructure the Simulator lacks. In the v1.0 study all 27 driver iterations
> failed to initialise the recogniser on **both** frameworks, and each app
> correctly surfaced the error per spec. If that happens here, record it as
> `blocked-simulator`, not `fail` — it is not a framework defect. Section 5 then
> needs a physical device, or gets reported as untested.

## Recording

- All items pass → `./acceptance.sh ns-vs-expo pass <trial>`
- Anything fails → `./acceptance.sh ns-vs-expo fail <trial> "<what you saw>"`

A failure permits exactly **one** remediation round, whose tokens are counted
into that trial (`PLAN.md` §4.5). Still failing after that = a failed trial, and
success rate is a first-class published result — not something to retry away.
