#!/usr/bin/env node
// Scores automated functional acceptance (run-acceptance.sh) into a pass/fail
// verdict per trial and a success rate per arm.
//
//   node analyze-acceptance.mjs <study-slug>
//
// The build gate proves an app compiles. This scores whether its SPEC flows
// actually reached their observable results, from the same XCUITest driver the
// latency suite uses.
//
// Speech is scored separately and never counted as a failure: SFSpeechRecognizer's
// server path rides Siri infrastructure the Simulator lacks, and it failed
// identically on both frameworks in the v1.0 study. It is an environment limit,
// not a defect, so it is reported as `blocked` and excluded from the verdict.

import fs from 'node:fs';
import path from 'node:path';
import { ROOT, getStudy } from '../lib/registry.mjs';

const slug = process.argv[2];
if (!slug) { console.error('usage: node analyze-acceptance.mjs <study-slug>'); process.exit(2); }
const study = getStudy(slug);
const dir = path.join(ROOT, study.resultsDir, 'acceptance');
if (!fs.existsSync(dir)) { console.error(`no acceptance data at ${path.relative(ROOT, dir)}`); process.exit(1); }

/** Checks that must hold for a trial to pass. Speech is deliberately excluded. */
const CHECKS = [
  ['navigates to Health', r => r.nav_health_ms != null],
  ['grants health access', r => r.health_granted === true],
  ['renders 7-day list', r => r.hk_rows_ms != null],
  ['log 500 refreshes list', r => r.hk_log_roundtrip_ms != null],
  ['navigates to Transcribe', r => r.nav_transcribe_ms != null],
];

const armOf = trial => study.frameworks.find(fw => trial.includes(`-${fw}-`)) ?? '?';
const rows = [];

for (const f of fs.readdirSync(dir).sort()) {
  if (!f.endsWith('.json')) continue;
  const j = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
  const trial = j.trial ?? f.replace(/\.json$/, '');
  // The driver emits one object per iteration under `runs`; take the first.
  const r = Array.isArray(j.runs) ? (j.runs[0] ?? {}) : j;
  const results = CHECKS.map(([label, fn]) => [label, j.status === 'undetermined' ? null : fn(r)]);
  const failed = results.filter(([, v]) => v === false).map(([l]) => l);
  const undetermined = j.status === 'undetermined';
  rows.push({
    trial,
    arm: armOf(trial),
    verdict: undetermined ? 'undetermined' : (failed.length ? 'FAIL' : 'pass'),
    failed,
    speech: r.speech_state ?? 'not reached',
  });
}

if (!rows.length) { console.error('no acceptance results found'); process.exit(1); }

console.log(`\n═══ functional acceptance — ${study.title} ═══\n`);
console.log('  trial          arm     verdict        speech               failures');
for (const r of rows) {
  console.log(
    `  ${r.trial.padEnd(14)} ${r.arm.padEnd(7)} ${r.verdict.padEnd(14)} ${String(r.speech).slice(0, 20).padEnd(20)} ${r.failed.join('; ')}`,
  );
}

console.log('\n  success rate (speech excluded — simulator-blocked on both arms):');
for (const fw of study.frameworks) {
  const a = rows.filter(r => r.arm === fw);
  const pass = a.filter(r => r.verdict === 'pass').length;
  const und = a.filter(r => r.verdict === 'undetermined').length;
  console.log(`    ${fw.padEnd(6)} ${pass}/${a.length} pass${und ? `  (${und} undetermined)` : ''}`);
}

const speechOk = rows.filter(r => r.speech === 'completed').length;
console.log(`\n  speech completed on ${speechOk}/${rows.length} apps${speechOk === 0 ? ' — consistent with the simulator limitation; needs a device' : ''}`);

const out = path.join(dir, '..', 'acceptance-summary.json');
fs.writeFileSync(out, JSON.stringify({ study: study.slug, rows }, null, 2) + '\n');
console.log(`\n  wrote ${path.relative(ROOT, out)}\n`);
