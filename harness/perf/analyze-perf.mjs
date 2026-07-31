#!/usr/bin/env node
// Aggregates <study>/perf/<trial>.json into <study>/perf/summary.json and
// prints per-trial and per-framework tables. Launch time preference order:
// SpringBoard 'launch_done' marker → 'active' marker → CPU-settle fallback
// (the chosen source is recorded per trial as launch_source).

// Usage: node analyze-perf.mjs <study-slug>

import fs from 'node:fs';
import path from 'node:path';
import { ROOT, getStudy } from '../lib/registry.mjs';

const slug = process.argv[2];
if (!slug) { console.error('usage: node analyze-perf.mjs <study-slug>'); process.exit(2); }
const study = getStudy(slug);
const PERF = path.join(ROOT, study.resultsDir, 'perf');
const FRAMEWORKS = study.frameworks;
const frameworkOf = trial => FRAMEWORKS.find(fw => trial.includes(`-${fw}-`)) ?? null;
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

if (!fs.existsSync(PERF)) { console.error(`no perf data at ${path.relative(ROOT, PERF)} — run measure.sh first`); process.exit(1); }
const trials = [];
for (const f of fs.readdirSync(PERF).sort()) {
  if (!f.endsWith('.json') || f.endsWith('-summary.json') || f === 'summary.json') continue;
  const t = JSON.parse(fs.readFileSync(path.join(PERF, f), 'utf8'));
  const fw = frameworkOf(t.trial);
  if (!fw) { console.error(`skipping ${t.trial}: no framework in study ${study.slug} matches`); continue; }

  const per = t.launches.map(l => ({
    done: l.markers.launch_done ?? null,
    active: l.markers.active ?? null,
    settle: l.cpu_settle_ms,
  }));
  const source = per.every(p => p.done != null) ? 'launch_done'
    : per.every(p => p.active != null) ? 'active' : 'cpu_settle';
  const times = per.map(p => source === 'launch_done' ? p.done : source === 'active' ? p.active : p.settle);

  const devtoolBytes = Object.entries(t.size.frameworks)
    .filter(([n]) => /devtool|debugrouter/i.test(n))
    .reduce((a, [, b]) => a + b, 0);

  trials.push({
    trial: t.trial, fw,
    bundle_mb: t.size.bundle_bytes / 1048576,
    installed_mb: t.size.installed_bytes / 1048576,
    executable_mb: t.size.executable_bytes / 1048576,
    frameworks_mb: Object.values(t.size.frameworks).reduce((a, b) => a + b, 0) / 1048576,
    devtool_mb: devtoolBytes / 1048576,
    launch_ms_median: median(times), launch_ms_range: mm(times),
    launch_source: source, launches_n: times.length,
    cpu_settle_ms_median: median(per.map(p => p.settle)),
    idle_rss_mb: t.idle.rss_kb_median / 1024,
    idle_footprint_mb: t.idle.phys_footprint_kb != null ? t.idle.phys_footprint_kb / 1024 : null,
    idle_cpu_pct: t.idle.cpu_pct_median,
    idle_cpu_pct_max: t.idle.cpu_pct_max,
  });
}
if (!trials.length) { console.error('no perf JSONs found — run measure.sh first'); process.exit(1); }

const agg = {};
for (const fw of FRAMEWORKS) {
  const rs = trials.filter(t => t.fw === fw);
  if (!rs.length) continue;
  const f = k => ({ median: median(rs.map(r => r[k])), range: mm(rs.map(r => r[k])) });
  agg[fw] = {
    n: rs.length,
    bundle_mb: f('bundle_mb'), installed_mb: f('installed_mb'), executable_mb: f('executable_mb'),
    frameworks_mb: f('frameworks_mb'), devtool_mb: f('devtool_mb'),
    launch_ms: f('launch_ms_median'), cpu_settle_ms: f('cpu_settle_ms_median'),
    idle_rss_mb: f('idle_rss_mb'), idle_footprint_mb: f('idle_footprint_mb'),
    idle_cpu_pct: f('idle_cpu_pct'),
    launch_sources: [...new Set(rs.map(r => r.launch_source))],
  };
}

fs.writeFileSync(path.join(PERF, 'summary.json'), JSON.stringify({ study: study.slug, trials, aggregates: agg }, null, 2) + '\n');

const f1 = n => n == null ? '—' : n.toFixed(1);
const f0 = n => n == null ? '—' : String(Math.round(n));
console.log('\nPer trial:');
console.log(['trial', 'bundle MB', 'installed MB', 'launch ms (src)', 'settle ms', 'idle RSS MB', 'idle CPU %'].join('\t'));
for (const t of trials) {
  console.log([t.trial, f1(t.bundle_mb), f1(t.installed_mb),
    `${f0(t.launch_ms_median)} (${t.launch_source})`, f0(t.cpu_settle_ms_median),
    f1(t.idle_rss_mb), f1(t.idle_cpu_pct)].join('\t'));
}
console.log('\nPer framework (median of trial medians, [min–max]):');
console.log(JSON.stringify(agg, null, 2));
console.log(`\nWrote ${path.relative(ROOT, path.join(PERF, 'summary.json'))}`);
