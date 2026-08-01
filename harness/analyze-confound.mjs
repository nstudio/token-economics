#!/usr/bin/env node
// Confound analysis for ns-vs-expo (PLAN-EXPO §14): does framework still predict
// token cost once interactive UI verification is controlled for? Answer: no — the
// sign flips. Kept in the harness so the correction is reproducible, not just asserted.
//
//   node analyze-confound.mjs

import fs from "node:fs";
const ROOT = "/Users/nstudio/Documents/github/NathanWalker/token-economics";
const s = JSON.parse(fs.readFileSync(`${ROOT}/results/ns-vs-expo/summary.json`, "utf8"));
const R = s.rows.filter(r => r.set === "main" && r.phase !== "R");
const tok = t => R.filter(r => r.trial === t).reduce((a, x) => a + x.output, 0);
const taps = t => {
  let n = 0;
  for (const ph of ["1", "2", "3"]) {
    const f = `${ROOT}/results/ns-vs-expo/${t}/phase-${ph}.jsonl`;
    if (!fs.existsSync(f)) continue;
    for (const l of fs.readFileSync(f, "utf8").split("\n")) {
      if (!l.trim()) continue;
      let e; try { e = JSON.parse(l); } catch { continue; }
      if (e.type !== "assistant") continue;
      for (const b of (e.message?.content || []))
        if (b.type === "tool_use" && b.name === "Bash" && /idb ui tap/.test(b.input?.command || "")) n++;
    }
  }
  return n;
};
const have = fw => [1,2,3,4,5,6,7,8].map(i => `main-${fw}-${i}`).filter(t => R.some(r => r.trial === t));
const D = [
  ...have("ns").map(t => ({ t, fw: 1, x: taps(t), y: tok(t) })),
  ...have("expo").map(t => ({ t, fw: 0, x: taps(t), y: tok(t) })),
];

// Solve OLS by Gauss-Jordan on the augmented normal equations.
function ols(X, Y) {
  const k = X[0].length, n = X.length;
  const A = Array.from({ length: k }, (_, i) =>
    Array.from({ length: k + 1 }, (_, j) =>
      j < k ? X.reduce((a, r, q) => a + r[i] * r[j], 0)
            : X.reduce((a, r, q) => a + r[i] * Y[q], 0)));
  for (let c = 0; c < k; c++) {
    let p = c;
    for (let r = c + 1; r < k; r++) if (Math.abs(A[r][c]) > Math.abs(A[p][c])) p = r;
    [A[c], A[p]] = [A[p], A[c]];
    const piv = A[c][c];
    for (let j = c; j <= k; j++) A[c][j] /= piv;
    for (let r = 0; r < k; r++) {
      if (r === c) continue;
      const f = A[r][c];
      for (let j = c; j <= k; j++) A[r][j] -= f * A[c][j];
    }
  }
  const b = A.map(r => r[k]);
  // (X'X)^-1 for standard errors
  const M = Array.from({ length: k }, (_, i) =>
    Array.from({ length: 2 * k }, (_, j) =>
      j < k ? X.reduce((a, r) => a + r[i] * r[j], 0) : (i === j - k ? 1 : 0)));
  for (let c = 0; c < k; c++) {
    let p = c;
    for (let r = c + 1; r < k; r++) if (Math.abs(M[r][c]) > Math.abs(M[p][c])) p = r;
    [M[c], M[p]] = [M[p], M[c]];
    const piv = M[c][c];
    for (let j = 0; j < 2 * k; j++) M[c][j] /= piv;
    for (let r = 0; r < k; r++) {
      if (r === c) continue;
      const f = M[r][c];
      for (let j = 0; j < 2 * k; j++) M[r][j] -= f * M[c][j];
    }
  }
  const inv = M.map(r => r.slice(k));
  const pred = X.map(r => r.reduce((a, v, i) => a + v * b[i], 0));
  const sse = Y.reduce((a, y, i) => a + (y - pred[i]) ** 2, 0);
  const sigma2 = sse / (n - k);
  const se = b.map((_, i) => Math.sqrt(sigma2 * inv[i][i]));
  const my = Y.reduce((a, y) => a + y, 0) / n;
  const sst = Y.reduce((a, y) => a + (y - my) ** 2, 0);
  return { b, se, t: b.map((v, i) => v / se[i]), r2: 1 - sse / sst, n, k };
}

console.log(`n = ${D.length} trials (${have("ns").length} NS, ${have("expo").length} Expo)\n`);

const m1 = ols(D.map(d => [1, d.fw]), D.map(d => d.y));
console.log("Model 1 — tokens ~ framework alone");
console.log(`  framework (NS vs Expo): ${m1.b[1].toFixed(0).padStart(8)} tokens   t=${m1.t[1].toFixed(2)}   R2=${m1.r2.toFixed(2)}`);

const m2 = ols(D.map(d => [1, d.x, d.fw]), D.map(d => d.y));
const crit = 2.16; // t(0.975, df≈13)
console.log("\nModel 2 — tokens ~ verification taps + framework");
console.log(`  taps:                   ${m2.b[1].toFixed(0).padStart(8)} tokens/tap  t=${m2.t[1].toFixed(2)}  ${Math.abs(m2.t[1]) > crit ? "SIGNIFICANT" : "n.s."}`);
console.log(`  framework (NS vs Expo): ${m2.b[2].toFixed(0).padStart(8)} tokens      t=${m2.t[2].toFixed(2)}  ${Math.abs(m2.t[2]) > crit ? "SIGNIFICANT" : "NOT significant"}`);
console.log(`  R2 = ${m2.r2.toFixed(2)}   (|t| > ~${crit} for p<0.05, df=${m2.n - m2.k})`);
