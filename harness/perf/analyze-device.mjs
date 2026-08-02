#!/usr/bin/env node
// Rolls the per-trial device-archive measurements into the medians and ranges the
// site publishes. Reads <study results>/perf/device/*.json.
//
// Usage: node analyze-device.mjs <study-slug>

import fs from 'node:fs';
import path from 'node:path';
import { getStudy, ROOT } from '../lib/registry.mjs';

const slug = process.argv[2];
if (!slug) {
  console.error('usage: analyze-device.mjs <study-slug>');
  process.exit(2);
}

const study = getStudy(slug);
const dir = path.join(ROOT, study.resultsDir, 'perf', 'device');
if (!fs.existsSync(dir)) {
  console.error(`no device measurements at ${dir} — run build-device.sh first`);
  process.exit(1);
}

const MB = b => b / 1048576;
const median = xs => {
  const s = [...xs].sort((a, b) => a - b);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};
const r1 = n => Math.round(n * 10) / 10;

const rows = fs
  .readdirSync(dir)
  .filter(f => f.endsWith('.json'))
  .map(f => JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')));

const out = { study: slug, byFramework: {} };

for (const fw of study.frameworks) {
  const rs = rows.filter(r => r.framework === fw);
  if (!rs.length) continue;

  // A trial that skipped the strip phase would drag the median up for reasons
  // that have nothing to do with the framework, so surface it rather than average
  // it in silently.
  const unstripped = rs.filter(r => r.symbols > 5000).map(r => r.trial);

  const bundles = rs.map(r => MB(r.bundle_bytes));
  const exes = rs.map(r => MB(r.executable_bytes));
  const fwTotals = rs.map(r => MB(Object.values(r.frameworks).reduce((a, b) => a + b, 0)));

  // Per-framework component medians, so the composition breakdown stays auditable.
  const names = [...new Set(rs.flatMap(r => Object.keys(r.frameworks)))];
  const components = Object.fromEntries(
    names
      .map(n => [n, r1(median(rs.map(r => MB(r.frameworks[n] ?? 0))))])
      .sort((a, b) => b[1] - a[1]),
  );

  out.byFramework[fw] = {
    n: rs.length,
    archs: [...new Set(rs.flatMap(r => r.archs))],
    unstripped,
    bundleMb: r1(median(bundles)),
    bundleRangeMb: [r1(Math.min(...bundles)), r1(Math.max(...bundles))],
    executableMb: r1(median(exes)),
    frameworksMb: r1(median(fwTotals)),
    components,
  };
}

const [a, b] = study.frameworks;
if (out.byFramework[a] && out.byFramework[b]) {
  const A = out.byFramework[a].bundleMb;
  const B = out.byFramework[b].bundleMb;
  out.ratio = {
    basis: a,
    bPctVsA: Math.round(((B - A) / A) * 100),
    label: `${b} is ${B < A ? '' : '+'}${Math.round(((B - A) / A) * 100)}% vs ${a}`,
  };
}

console.log(JSON.stringify(out, null, 2));
