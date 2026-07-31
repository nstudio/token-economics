#!/usr/bin/env node
// Aggregates <study>/perf/interactions/<trial>.json into
// <study>/perf/interactions-summary.json and prints per-trial + per-framework
// medians for the feature-path latency metrics.
//
// Usage: node analyze-interactions.mjs <study-slug>

import fs from 'node:fs';
import path from 'node:path';
import { ROOT, getStudy } from '../lib/registry.mjs';

const slug = process.argv[2];
if (!slug) { console.error('usage: node analyze-interactions.mjs <study-slug>'); process.exit(2); }
const study = getStudy(slug);
const DIR = path.join(ROOT, study.resultsDir, 'perf', 'interactions');
const FRAMEWORKS = study.frameworks;
const METRICS = ['nav_health_ms', 'hk_rows_ms', 'hk_log_roundtrip_ms', 'nav_transcribe_ms', 'speech_wall_ms'];

const median = xs => {
  const s = xs.filter(x => x != null && !Number.isNaN(x)).sort((a, b) => a - b);
  if (!s.length) return null;
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};
const mm = xs => {
  const s = xs.filter(x => x != null).sort((a, b) => a - b);
  return s.length ? [s[0], s[s.length - 1]] : [null, null];
};
const frameworkOf = trial => FRAMEWORKS.find(fw => trial.includes(`-${fw}-`)) ?? null;

if (!fs.existsSync(DIR)) { console.error(`no interaction data at ${path.relative(ROOT, DIR)}`); process.exit(1); }
const trials = [];
for (const f of fs.readdirSync(DIR).sort()) {
  if (!f.endsWith('.json')) continue;
  const t = JSON.parse(fs.readFileSync(path.join(DIR, f), 'utf8'));
  const fw = frameworkOf(t.trial);
  if (!fw) { console.error(`skipping ${t.trial}: no framework in study ${study.slug} matches`); continue; }
  const row = { trial: t.trial, fw, iters: t.runs.length };
  for (const m of METRICS) row[m] = median(t.runs.map(r => r[m]));
  row.speech_states = [...new Set(t.runs.map(r => r.speech_state).filter(Boolean))];
  row.speech_app_reported_s = median(t.runs.map(r => r.speech_app_reported_s));
  row.granted = t.runs.every(r => r.health_granted && r.speech_granted);
  trials.push(row);
}
if (!trials.length) { console.error('no interaction JSONs found'); process.exit(1); }

const agg = {};
for (const fw of FRAMEWORKS) {
  const rs = trials.filter(t => t.fw === fw);
  if (!rs.length) continue;
  agg[fw] = { n: rs.length, speech_states: [...new Set(rs.flatMap(r => r.speech_states))] };
  // Per-metric n can differ from trial n: a driver that cannot match one app's
  // affordance leaves that metric null rather than dropping the trial.
  for (const m of METRICS) {
    const vals = rs.map(r => r[m]).filter(v => v != null);
    agg[fw][m] = { n: vals.length, median: median(vals), range: mm(vals) };
  }
}

const out = path.join(DIR, '..', 'interactions-summary.json');
fs.writeFileSync(out, JSON.stringify({ study: study.slug, trials, aggregates: agg }, null, 2) + '\n');

const f0 = n => n == null ? '—' : String(Math.round(n));
console.log('\nPer trial (median of iterations, ms):');
console.log(['trial', 'fw', 'nav_health', 'hk_rows', 'hk_log_rt', 'nav_transcribe', 'speech_wall', 'speech_state'].join('\t'));
for (const t of trials) {
  console.log([t.trial, t.fw, f0(t.nav_health_ms), f0(t.hk_rows_ms), f0(t.hk_log_roundtrip_ms),
    f0(t.nav_transcribe_ms), f0(t.speech_wall_ms), t.speech_states.join('|') || '—'].join('\t'));
}
console.log('\nPer framework:');
console.log(JSON.stringify(agg, null, 2));
console.log(`\nWrote ${path.relative(ROOT, out)}`);
