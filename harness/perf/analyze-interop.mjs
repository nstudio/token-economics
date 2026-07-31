#!/usr/bin/env node
// Aggregates <study>/perf/interop/<fw>-run<N>.json into interop-summary.json:
// per-scenario median ms across runs per framework, plus cross-checks that
// the workloads produced identical `check` values on every side.
//
// Usage: node analyze-interop.mjs <study-slug>
//
// The study's first framework is the ratio baseline, so a two-arm study reads
// as "how many times slower is arm B than arm A" on each scenario.

import fs from 'node:fs';
import path from 'node:path';
import { ROOT, getStudy } from '../lib/registry.mjs';

const slug = process.argv[2];
if (!slug) { console.error('usage: node analyze-interop.mjs <study-slug>'); process.exit(2); }
const study = getStudy(slug);
const DIR = path.join(ROOT, study.resultsDir, 'perf', 'interop');
const FRAMEWORKS = study.frameworks;
const [BASE] = FRAMEWORKS;

const median = (xs) => {
  const s = xs.filter((x) => x != null).sort((a, b) => a - b);
  return s.length ? s[s.length >> 1] : null;
};

if (!fs.existsSync(DIR)) { console.error(`no interop runs at ${path.relative(ROOT, DIR)}`); process.exit(1); }
const runs = Object.fromEntries(FRAMEWORKS.map((fw) => [fw, []]));
const namePattern = new RegExp(`^(${FRAMEWORKS.join('|')})-run\\d+\\.json$`);
for (const f of fs.readdirSync(DIR).sort()) {
  const m = f.match(namePattern);
  if (!m) continue;
  runs[m[1]].push(JSON.parse(fs.readFileSync(path.join(DIR, f), 'utf8')));
}
const missing = FRAMEWORKS.filter((fw) => !runs[fw].length);
if (missing.length) {
  console.error(`need at least one run per framework in ${path.relative(ROOT, DIR)} — missing: ${missing.join(', ')}`);
  process.exit(1);
}

const scenarioIds = runs[BASE][0].r.map((s) => s.id);
const summary = {
  study: study.slug,
  baseline: BASE,
  runs: Object.fromEntries(FRAMEWORKS.map((fw) => [fw, runs[fw].length])),
  scenarios: [],
};
for (const id of scenarioIds) {
  const byFw = Object.fromEntries(FRAMEWORKS.map((fw) => [
    fw, runs[fw].map((run) => run.r.find((s) => s.id === id)).filter(Boolean),
  ]));
  const baseMs = median(byFw[BASE].map((s) => s.ms));
  // A scenario is only comparable if every framework computed the same answer.
  const checksMatch = new Set(FRAMEWORKS.flatMap((fw) => byFw[fw].map((s) => s.check))).size === 1;
  const row = { id, ops: byFw[BASE][0]?.ops ?? null, checks_match: checksMatch, ms: {}, per_op_us: {}, ratio_over_baseline: {} };
  for (const fw of FRAMEWORKS) {
    const ms = median(byFw[fw].map((s) => s.ms));
    row.ms[fw] = ms;
    row.per_op_us[fw] = byFw[fw][0]?.perOpUs != null ? median(byFw[fw].map((s) => s.perOpUs)) : null;
    row.ratio_over_baseline[fw] = baseMs ? +(ms / baseMs).toFixed(1) : null;
  }
  summary.scenarios.push(row);
}

const out = path.join(DIR, '..', 'interop-summary.json');
fs.writeFileSync(out, JSON.stringify(summary, null, 2) + '\n');

console.log(['scenario', 'ops', ...FRAMEWORKS.map((f) => `${f} ms`), ...FRAMEWORKS.map((f) => `${f} µs/op`), 'checks'].join('\t'));
for (const s of summary.scenarios) {
  console.log([
    s.id, s.ops,
    ...FRAMEWORKS.map((f) => (f === BASE ? s.ms[f] : `${s.ms[f]} (${s.ratio_over_baseline[f]}×)`)),
    ...FRAMEWORKS.map((f) => s.per_op_us[f] ?? '—'),
    s.checks_match ? 'match' : 'MISMATCH',
  ].join('\t'));
}
const mismatched = summary.scenarios.filter((s) => !s.checks_match).map((s) => s.id);
if (mismatched.length) console.log(`\n⚠️  check mismatch — workloads not identical for: ${mismatched.join(', ')}`);
console.log(`\nWrote ${path.relative(ROOT, out)}`);
