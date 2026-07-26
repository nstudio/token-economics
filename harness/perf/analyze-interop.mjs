#!/usr/bin/env node
// Aggregates results/perf/interop/<fw>-run<N>.json into interop-summary.json:
// per-scenario median ms across runs per framework, plus cross-checks that
// the workloads produced identical `check` values on both sides.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'results', 'perf', 'interop');
const median = (xs) => {
  const s = xs.filter((x) => x != null).sort((a, b) => a - b);
  return s.length ? s[s.length >> 1] : null;
};

const runs = { ns: [], lynx: [] };
for (const f of fs.readdirSync(DIR).sort()) {
  const m = f.match(/^(ns|lynx)-run\d+\.json$/);
  if (!m) continue;
  runs[m[1]].push(JSON.parse(fs.readFileSync(path.join(DIR, f), 'utf8')));
}
if (!runs.ns.length || !runs.lynx.length) {
  console.error('need at least one run per framework in results/perf/interop/');
  process.exit(1);
}

const scenarioIds = runs.ns[0].r.map((s) => s.id);
const summary = { runs: { ns: runs.ns.length, lynx: runs.lynx.length }, scenarios: [] };
for (const id of scenarioIds) {
  const pick = (fw) => runs[fw].map((run) => run.r.find((s) => s.id === id)).filter(Boolean);
  const ns = pick('ns');
  const lynx = pick('lynx');
  const nsMs = median(ns.map((s) => s.ms));
  const lynxMs = median(lynx.map((s) => s.ms));
  const checksMatch = new Set([...ns, ...lynx].map((s) => s.check)).size === 1;
  summary.scenarios.push({
    id,
    ops: ns[0]?.ops ?? null,
    ns_ms: nsMs,
    lynx_ms: lynxMs,
    ns_per_op_us: ns[0]?.perOpUs != null ? median(ns.map((s) => s.perOpUs)) : null,
    lynx_per_op_us: lynx[0]?.perOpUs != null ? median(lynx.map((s) => s.perOpUs)) : null,
    ratio_lynx_over_ns: nsMs ? +(lynxMs / nsMs).toFixed(1) : null,
    checks_match: checksMatch,
  });
}

fs.writeFileSync(path.join(DIR, '..', 'interop-summary.json'), JSON.stringify(summary, null, 2) + '\n');
console.log(['scenario', 'ops', 'ns ms', 'lynx ms', 'ratio', 'ns µs/op', 'lynx µs/op', 'checks'].join('\t'));
for (const s of summary.scenarios) {
  console.log([s.id, s.ops, s.ns_ms, s.lynx_ms, s.ratio_lynx_over_ns + '×',
    s.ns_per_op_us ?? '—', s.lynx_per_op_us ?? '—', s.checks_match ? 'match' : 'MISMATCH'].join('\t'));
}
console.log('\nWrote results/perf/interop-summary.json');
