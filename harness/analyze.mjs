#!/usr/bin/env node
// Token-economics analyzer (see ../PLAN.md §5).
// Reads results/<trial>/ artifacts, emits results/summary.csv + results/summary.json,
// prints a per-trial table and per-framework×phase medians.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HARNESS = path.dirname(fileURLToPath(import.meta.url));
const RESULTS = path.join(HARNESS, '..', 'results');

const READ_TOOLS = new Set(['Read', 'Glob', 'Grep']);
const EDIT_TOOLS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit']);
const WEB_TOOLS = new Set(['WebFetch', 'WebSearch']);
// Files under these roots (or with these extensions) count as native-side code.
const NATIVE_ROOTS = ['ios/', 'App_Resources/', 'platforms/'];
const NATIVE_EXTS = new Set(['swift', 'h', 'm', 'mm', 'pbxproj', 'plist', 'entitlements', 'xcconfig', 'storyboard', 'modulemap']);

function readJSON(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return null; }
}

function analyzeTranscript(file) {
  const out = {
    input: 0, output: 0, cache_write: 0, cache_read: 0,
    reads: 0, edits: 0, bash: 0, mcp_docs: 0, web: 0, tasks: 0, other_tools: 0,
    first_ts: null, last_ts: null,
  };
  if (!fs.existsSync(file)) return null;
  const usageById = new Map();
  let anonUsage = [];
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    let e; try { e = JSON.parse(line); } catch { continue; }
    if (e.timestamp) {
      if (!out.first_ts) out.first_ts = e.timestamp;
      out.last_ts = e.timestamp;
    }
    const msg = e.message;
    if (e.type !== 'assistant' || !msg) continue;
    if (msg.usage) {
      // The same message id can appear once per content block — keep the last snapshot per id.
      if (msg.id) usageById.set(msg.id, msg.usage);
      else anonUsage.push(msg.usage);
    }
    for (const block of Array.isArray(msg.content) ? msg.content : []) {
      if (block.type !== 'tool_use') continue;
      const n = block.name || '';
      if (READ_TOOLS.has(n)) out.reads++;
      else if (EDIT_TOOLS.has(n)) out.edits++;
      else if (n === 'Bash') out.bash++;
      else if (n.startsWith('mcp__') || n.includes('McpResource')) out.mcp_docs++;
      else if (WEB_TOOLS.has(n)) out.web++;
      else if (n === 'Task') out.tasks++;
      else out.other_tools++;
    }
  }
  for (const u of [...usageById.values(), ...anonUsage]) {
    out.input += u.input_tokens ?? 0;
    out.output += u.output_tokens ?? 0;
    out.cache_write += u.cache_creation_input_tokens ?? 0;
    out.cache_read += u.cache_read_input_tokens ?? 0;
  }
  return out;
}

function analyzeNumstat(file) {
  const out = { files_changed: 0, loc_js_added: 0, loc_native_added: 0 };
  if (!fs.existsSync(file)) return out;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const m = line.match(/^(\d+|-)\t(\d+|-)\t(.+)$/);
    if (!m) continue;
    out.files_changed++;
    if (m[1] === '-') continue; // binary
    const added = Number(m[1]);
    const p = m[3];
    const ext = (p.split('.').pop() || '').toLowerCase();
    const native = NATIVE_ROOTS.some(r => p.startsWith(r)) || NATIVE_EXTS.has(ext);
    if (native) out.loc_native_added += added;
    else out.loc_js_added += added;
  }
  return out;
}

function median(xs) {
  const s = xs.filter(x => typeof x === 'number' && !Number.isNaN(x)).sort((a, b) => a - b);
  if (!s.length) return null;
  const mid = s.length >> 1;
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

// ---------------------------------------------------------------- collect
const rows = [];
if (!fs.existsSync(RESULTS)) {
  console.error(`no results directory at ${RESULTS}`);
  process.exit(1);
}
for (const trial of fs.readdirSync(RESULTS).sort()) {
  const dir = path.join(RESULTS, trial);
  const manifest = readJSON(path.join(dir, 'manifest.json'));
  if (!manifest) continue;
  for (const phase of ['1', '2', '3', 'R']) {
    const p = manifest.phases?.[phase];
    if (!p) continue;
    const t = analyzeTranscript(path.join(dir, `phase-${phase}.jsonl`)) ?? {};
    const d = analyzeNumstat(path.join(dir, 'diffs', `phase-${phase}.numstat`));
    const wall = t.first_ts && t.last_ts
      ? (new Date(t.last_ts) - new Date(t.first_ts)) / 1000
      : (p.duration_ms != null ? p.duration_ms / 1000 : null);
    rows.push({
      trial, framework: manifest.framework, model: manifest.model, phase,
      build_pass: p.build_pass ?? null,
      capped: p.is_error ?? null,
      outcome: manifest.outcome ?? null,
      acceptance: manifest.acceptance?.status ?? null,
      input: t.input ?? null, output: t.output ?? null,
      cache_write: t.cache_write ?? null, cache_read: t.cache_read ?? null,
      total_cost_usd: p.total_cost_usd ?? null,
      turns: p.num_turns ?? null,
      wall_s: wall != null ? Math.round(wall) : null,
      reads: t.reads ?? null, edits: t.edits ?? null, bash: t.bash ?? null,
      mcp_docs: t.mcp_docs ?? null, web: t.web ?? null, tasks: t.tasks ?? null,
      other_tools: t.other_tools ?? null,
      ...d,
    });
  }
}
if (!rows.length) {
  console.error('no trials found under results/');
  process.exit(1);
}

// ---------------------------------------------------------------- emit CSV
const cols = Object.keys(rows[0]);
const csv = [cols.join(',')]
  .concat(rows.map(r => cols.map(c => r[c] ?? '').join(',')))
  .join('\n');
fs.writeFileSync(path.join(RESULTS, 'summary.csv'), csv + '\n');

// ---------------------------------------------------------------- aggregates
const NUMERIC = ['input', 'output', 'cache_write', 'cache_read', 'total_cost_usd', 'turns', 'wall_s', 'mcp_docs', 'web', 'loc_js_added', 'loc_native_added'];
const aggregates = {};
for (const fw of ['ns', 'lynx']) {
  aggregates[fw] = {};
  for (const phase of ['1', '2', '3', 'R', 'total']) {
    const sample = phase === 'total'
      ? Object.values(Object.groupBy(rows.filter(r => r.framework === fw && r.phase !== 'R'), r => r.trial))
          .map(trialRows => Object.fromEntries(NUMERIC.map(c => [c, trialRows.reduce((a, r) => a + (r[c] ?? 0), 0)])))
      : rows.filter(r => r.framework === fw && r.phase === phase);
    if (!sample.length) continue;
    aggregates[fw][phase === 'total' ? 'total_per_trial' : `phase_${phase}`] = {
      n: sample.length,
      ...Object.fromEntries(NUMERIC.map(c => [`median_${c}`, median(sample.map(r => r[c]))])),
    };
  }
}
fs.writeFileSync(path.join(RESULTS, 'summary.json'), JSON.stringify({ rows, aggregates }, null, 2) + '\n');

// ---------------------------------------------------------------- print
const fmt = n => n == null ? '—' : (typeof n === 'number' && !Number.isInteger(n) ? n.toFixed(2) : String(n));
console.log('\nPer trial × phase:');
console.log(['trial', 'fw', 'ph', 'build', 'capped', 'input', 'output', 'cache_w', 'cache_r', 'cost$', 'turns', 'wall_s', 'docs', 'loc_js', 'loc_nat'].join('\t'));
for (const r of rows) {
  console.log([r.trial, r.framework, r.phase, r.build_pass === null ? '—' : (r.build_pass ? 'ok' : 'FAIL'), r.capped === null ? '—' : (r.capped ? 'YES' : 'no'),
    fmt(r.input), fmt(r.output), fmt(r.cache_write), fmt(r.cache_read), fmt(r.total_cost_usd),
    fmt(r.turns), fmt(r.wall_s), fmt(r.mcp_docs), fmt(r.loc_js_added), fmt(r.loc_native_added)].join('\t'));
}
console.log('\nMedians (per framework × phase, plus per-trial totals over phases 1–3):');
console.log(JSON.stringify(aggregates, null, 2));
console.log(`\nWrote results/summary.csv and results/summary.json`);
