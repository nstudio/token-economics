#!/usr/bin/env node
// Verification-effort confound diagnostic (PLAN-EXPO §14, §15).
//
//   node analyze-confound.mjs <study-slug>
//
// Agents choose how much to drive the simulator UI, and that choice costs tokens.
// When a study's two arms verify at different rates, the headline token ratio
// measures that choice rather than the frameworks. This reports the asymmetry and
// asks whether framework still predicts cost once verification is controlled for.
//
// Run it on every study before publishing a ratio. In ns-vs-lynx the arms verified
// comparably and the published result held; in ns-vs-expo they differed ~3.5x and the
// framework coefficient changed sign.

import fs from 'node:fs';
import path from 'node:path';
import { ROOT, getStudy } from './lib/registry.mjs';

const slug = process.argv[2];
if (!slug) { console.error('usage: node analyze-confound.mjs <study-slug>'); process.exit(2); }
const study = getStudy(slug);
const dir = path.join(ROOT, study.resultsDir);
const [ARM_A, ARM_B] = study.frameworks;

const rows = JSON.parse(fs.readFileSync(path.join(dir, 'summary.json'), 'utf8'))
  .rows.filter(r => r.set === 'main' && r.phase !== 'R');

const tokens = t => rows.filter(r => r.trial === t).reduce((a, x) => a + x.output, 0);

/** Bash calls that drive the simulator UI — the verification-effort proxy. */
const UI_CALL = /idb ui tap|idb ui describe|simctl\s+(ui|launch)/;
function uiCalls(trial) {
  let n = 0;
  for (const phase of study.phases.map(p => p.id)) {
    const f = path.join(dir, trial, `phase-${phase}.jsonl`);
    if (!fs.existsSync(f)) continue;
    for (const line of fs.readFileSync(f, 'utf8').split('\n')) {
      if (!line.trim()) continue;
      let e; try { e = JSON.parse(line); } catch { continue; }
      if (e.type !== 'assistant') continue;
      for (const b of (e.message?.content || []))
        if (b.type === 'tool_use' && b.name === 'Bash' && UI_CALL.test(b.input?.command || '')) n++;
    }
  }
  return n;
}

const trialsFor = fw => [...new Set(rows.filter(r => r.framework === fw).map(r => r.trial))].sort();
const data = [ARM_A, ARM_B].flatMap((fw, i) =>
  trialsFor(fw).map(t => ({ trial: t, arm: i, x: uiCalls(t), y: tokens(t) })));

if (data.length < 6) { console.error('too few trials for this diagnostic'); process.exit(1); }

const mean = a => a.reduce((p, q) => p + q, 0) / a.length;
const sd = a => Math.sqrt(mean(a.map(x => (x - mean(a)) ** 2)));
const corr = (A, B) => mean(A.map((_, i) => (A[i] - mean(A)) * (B[i] - mean(B)))) / (sd(A) * sd(B));
const med = a => { const q = [...a].sort((p, r) => p - r); return q.length % 2 ? q[q.length >> 1] : (q[q.length / 2 - 1] + q[q.length / 2]) / 2; };

/** OLS with standard errors, via Gauss-Jordan on the normal equations. */
function ols(X, Y) {
  const k = X[0].length, n = X.length;
  const solve = (aug, cols) => {
    for (let c = 0; c < k; c++) {
      let p = c;
      for (let r = c + 1; r < k; r++) if (Math.abs(aug[r][c]) > Math.abs(aug[p][c])) p = r;
      [aug[c], aug[p]] = [aug[p], aug[c]];
      const piv = aug[c][c];
      for (let j = 0; j < cols; j++) aug[c][j] /= piv;
      for (let r = 0; r < k; r++) {
        if (r === c) continue;
        const f = aug[r][c];
        for (let j = 0; j < cols; j++) aug[r][j] -= f * aug[c][j];
      }
    }
    return aug;
  };
  const A = solve(Array.from({ length: k }, (_, i) =>
    Array.from({ length: k + 1 }, (_, j) =>
      j < k ? X.reduce((a, r) => a + r[i] * r[j], 0)
            : X.reduce((a, r, q) => a + r[i] * Y[q], 0))), k + 1);
  const b = A.map(r => r[k]);
  const M = solve(Array.from({ length: k }, (_, i) =>
    Array.from({ length: 2 * k }, (_, j) =>
      j < k ? X.reduce((a, r) => a + r[i] * r[j], 0) : (i === j - k ? 1 : 0))), 2 * k);
  const inv = M.map(r => r.slice(k));
  const pred = X.map(r => r.reduce((a, v, i) => a + v * b[i], 0));
  const sse = Y.reduce((a, y, i) => a + (y - pred[i]) ** 2, 0);
  const sigma2 = sse / (n - k);
  const my = mean(Y), sst = Y.reduce((a, y) => a + (y - my) ** 2, 0);
  return {
    b, t: b.map((v, i) => v / Math.sqrt(sigma2 * inv[i][i])),
    r2: 1 - sse / sst, df: n - k,
  };
}

const A = data.filter(d => d.arm === 0), B = data.filter(d => d.arm === 1);
console.log(`\n═══ verification-effort confound — ${study.title} ═══\n`);
console.log(`  ${ARM_A.padEnd(6)} n=${A.length}  UI calls median ${String(med(A.map(d => d.x))).padStart(3)}  tokens median ${med(A.map(d => d.y))}`);
console.log(`  ${ARM_B.padEnd(6)} n=${B.length}  UI calls median ${String(med(B.map(d => d.x))).padStart(3)}  tokens median ${med(B.map(d => d.y))}`);

const ratio = med(A.map(d => d.x)) / Math.max(med(B.map(d => d.x)), 0.5);
const asym = ratio > 1.5 || ratio < 0.67;
console.log(`\n  verification asymmetry ${ratio.toFixed(1)}x — ${asym ? 'HEADLINE RATIO IS NOT A FRAMEWORK RESULT' : 'arms verify comparably, ratio is interpretable'}`);
console.log(`  r(UI calls, tokens) pooled = ${corr(data.map(d => d.x), data.map(d => d.y)).toFixed(2)}`);

const m1 = ols(data.map(d => [1, d.arm]), data.map(d => d.y));
const m2 = ols(data.map(d => [1, d.x, d.arm]), data.map(d => d.y));
const crit = 2.16;
console.log(`\n  model 1  tokens ~ arm       : arm ${m1.b[1].toFixed(0).padStart(8)}   t=${m1.t[1].toFixed(2).padStart(6)}   R2=${m1.r2.toFixed(2)}`);
console.log(`  model 2  tokens ~ UI + arm  : UI  ${m2.b[1].toFixed(0).padStart(8)}/c t=${m2.t[1].toFixed(2).padStart(6)}   ${Math.abs(m2.t[1]) > crit ? 'sig' : 'n.s.'}`);
console.log(`                               arm ${m2.b[2].toFixed(0).padStart(8)}   t=${m2.t[2].toFixed(2).padStart(6)}   ${Math.abs(m2.t[2]) > crit ? 'sig' : 'n.s.'}   R2=${m2.r2.toFixed(2)}`);
if (Math.sign(m1.b[1]) !== Math.sign(m2.b[2])) {
  console.log(`\n  The arm coefficient CHANGES SIGN once verification is controlled for:`);
  console.log(`  the raw comparison reports the opposite of the controlled one.`);
}
console.log();
