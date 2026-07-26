#!/usr/bin/env node
// Aggregates results/perf/interactions/<trial>.json into
// results/perf/interactions-summary.json and prints per-trial + per-framework
// medians for the feature-path latency metrics.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'results', 'perf', 'interactions');
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

const trials = [];
for (const f of fs.readdirSync(DIR).sort()) {
  if (!f.endsWith('.json')) continue;
  const t = JSON.parse(fs.readFileSync(path.join(DIR, f), 'utf8'));
  const fw = t.trial.includes('-ns-') ? 'ns' : 'lynx';
  const row = { trial: t.trial, fw, iters: t.runs.length };
  for (const m of METRICS) row[m] = median(t.runs.map(r => r[m]));
  row.speech_states = [...new Set(t.runs.map(r => r.speech_state).filter(Boolean))];
  row.speech_app_reported_s = median(t.runs.map(r => r.speech_app_reported_s));
  row.granted = t.runs.every(r => r.health_granted && r.speech_granted);
  trials.push(row);
}
if (!trials.length) { console.error('no interaction JSONs found'); process.exit(1); }

const agg = {};
for (const fw of ['ns', 'lynx']) {
  const rs = trials.filter(t => t.fw === fw);
  if (!rs.length) continue;
  agg[fw] = { n: rs.length, speech_states: [...new Set(rs.flatMap(r => r.speech_states))] };
  for (const m of METRICS) agg[fw][m] = { median: median(rs.map(r => r[m])), range: mm(rs.map(r => r[m])) };
}
fs.writeFileSync(path.join(DIR, '..', 'interactions-summary.json'), JSON.stringify({ trials, aggregates: agg }, null, 2) + '\n');

const f0 = n => n == null ? '—' : String(Math.round(n));
console.log('\nPer trial (median of iterations, ms):');
console.log(['trial', 'nav_health', 'hk_rows', 'hk_log_rt', 'nav_transcribe', 'speech_wall', 'speech_state'].join('\t'));
for (const t of trials) {
  console.log([t.trial, f0(t.nav_health_ms), f0(t.hk_rows_ms), f0(t.hk_log_roundtrip_ms),
    f0(t.nav_transcribe_ms), f0(t.speech_wall_ms), t.speech_states.join('|') || '—'].join('\t'));
}
console.log('\nPer framework:');
console.log(JSON.stringify(agg, null, 2));
console.log('\nWrote results/perf/interactions-summary.json');
