# Native Bench — App Specification

This document is the single source of truth for the app's behavior. Implement only the section you were asked to implement. Do not modify this file or anything under `spec-assets/`.

## 1. Overview

Native Bench is an iOS app with a Home screen and two feature screens:

- **Health** — logs and displays step data using the platform health store (HealthKit).
- **Transcribe** — transcribes a bundled audio file using platform speech recognition (Speech framework).

Target: iOS Simulator, iOS 16 or later. The app must never crash, including when the user denies a permission.

## 2. General rules (apply to every section)

- Use Vue 3 idioms as supported by this project's framework; prefer TypeScript wherever the project supports it.
- Implement only what the assigned section specifies — do not scaffold ahead for later sections.
- All user-visible labels must match this spec **exactly**; they are checked during acceptance.
- Any native error must surface as human-readable text in the affected screen's status line — never a silent failure, never console-only.
- Styling: clean, readable, native-feeling spacing and typography, at the implementer's discretion. There are no pixel-level requirements.
- Numbers use thousands separators (e.g. `1,000`); acceptance runs use the en-US locale.

## 3. Phase 1 — App shell

Three screens with working navigation. No native platform calls in this phase; feature screens are static placeholders.

### 3.1 Home screen
- Title: `Native Bench`
- Subtitle: `Token economics benchmark`
- Two buttons: `Health` and `Transcribe`, each navigating to its screen.
- Each feature screen provides a way to navigate back to Home.

### 3.2 Health screen (placeholder)
- Status line: `Health access: not requested`
- Button `Request Access` — enabled; no behavior yet.
- Button `Log 500 Steps` — disabled.
- Section header: `Last 7 Days`
- Empty state text: `No data yet`

### 3.3 Transcribe screen (placeholder)
- Status line: `Speech access: not requested`
- Button `Request Access` — enabled; no behavior yet.
- Button `Transcribe Sample` — disabled.
- Transcript area empty state: `No transcript yet`

## 4. Phase 2 — Health (HealthKit)

Wire the Health screen to the platform health store for the **step count** type, read and write.

### 4.1 Authorization
- The status line reflects the step type's sharing (write) authorization status:
  - not determined → `Health access: not requested`
  - authorized → `Health access: granted`
  - denied → `Health access: denied`
- `Request Access` requests read + write authorization for step count, then updates the status line and button states.
- The status line is refreshed every time the screen is shown.

### 4.2 Logging steps
- `Log 500 Steps` is enabled only when access is granted.
- Tapping it saves a quantity sample of **500 steps** with start time = end time = now.
- After a successful save, the Last 7 Days list refreshes. A failed save surfaces its error in the status line.

### 4.3 Last 7 Days list
- Visible when access is granted; loads when the screen is shown and after each successful log.
- Exactly 7 rows, most recent day first. Each row: day label, then step total with thousands separators, in the format `Fri Jul 25 — 1,000 steps` (weekday and month abbreviated). Days with no data show `0 steps`.
- Today's row is visually emphasized and suffixed ` (today)`.
- Totals are daily sums of the step count type from the health store (all sources).
- If access is denied, the list area shows `Health access needed` instead of rows.

## 5. Phase 3 — Transcribe (Speech)

Wire the Transcribe screen to platform speech recognition, transcribing the audio file at `spec-assets/sample.wav`.

### 5.1 Bundling
- Ship `spec-assets/sample.wav` inside the app bundle and load it from the bundle at runtime. Do not stream it from disk paths outside the bundle.

### 5.2 Authorization
- The status line reflects speech recognition authorization:
  - not determined → `Speech access: not requested`
  - authorized → `Speech access: granted`
  - denied or restricted → `Speech access: denied`
- `Request Access` requests speech recognition authorization, then updates the status line and button states.
- The status line is refreshed every time the screen is shown.

### 5.3 Transcription
- `Transcribe Sample` is enabled only when access is granted and no transcription is running.
- Tapping it starts recognition of the bundled file with **partial results enabled**. Either on-device or server-based recognition is acceptable.
- While running: the button is disabled, the status line shows `Transcribing…`, and the transcript area updates live with the latest partial transcription as results stream in.
- On completion: the transcript area shows the final transcription, and directly beneath it a line `Completed in N.N s` — wall-clock seconds from tap to final result, one decimal place.
- On failure: the error is shown in the status line and the button re-enables.

## 6. Acceptance checklist (run by the operator after all phases)

- Home shows both buttons; both feature screens are reachable and can navigate back.
- Health: request → grant → status becomes `Health access: granted`; tapping `Log 500 Steps` twice results in today's row showing at least `1,000 steps (today)`; relaunching the app preserves the data; all labels match §4.
- Transcribe: request → grant → status becomes `Speech access: granted`; tapping `Transcribe Sample` shows visibly streaming partial text, then a final transcript whose case- and punctuation-insensitive word overlap with `spec-assets/reference-transcript.txt` is at least 90%, plus a `Completed in N.N s` line.
- Deny paths (fresh install, deny each permission): status shows `denied`, action buttons stay disabled, no crash.
