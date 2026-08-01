#!/usr/bin/env node
// Token-economics analyzer (see ../PLAN.md §5).
//
// Usage:
//   node analyze.mjs              # every study in the registry
//   node analyze.mjs ns-vs-expo   # one study
//
// Per study, reads <resultsDir>/<trial>/ artifacts and writes <resultsDir>/summary.csv
// and <resultsDir>/summary.json, then prints a per-trial table and medians.
//
// Studies are analyzed independently and never pooled: a median is only meaningful
// within one spec version, one model, and one measurement window.

import fs from 'node:fs';
import path from 'node:path';
import {
  ROOT, listStudies, getStudy, getFramework, trialSet, classifyPath,
} from './lib/registry.mjs';

const READ_TOOLS = new Set(['Read', 'Glob', 'Grep']);
const EDIT_TOOLS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit']);
const WEB_TOOLS = new Set(['WebFetch', 'WebSearch']);

function readJSON(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return null; }
}

function analyzeTranscript(file) {
  const out = {
    input: 0, output: 0, cache_write: 0, cache_read: 0,
    reads: 0, edits: 0, bash: 0, mcp_docs: 0, web: 0, tasks: 0, other_tools: 0,
    first_ts: null, last_ts: null, first_turn_context: null,
  };
  if (!fs.existsSync(file)) return null;
  const usageById = new Map();
  const anonUsage = [];
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
      // Turn 1 pays for the whole fixed prefix: system prompt, CLAUDE.md, and every
      // MCP tool schema. CLAUDE.md files are structurally identical by protocol, so
      // the cross-arm delta here is dominated by MCP schema weight (PLAN §4.3).
      if (out.first_turn_context === null) {
        out.first_turn_context =
          (msg.usage.cache_creation_input_tokens ?? 0) +
          (msg.usage.cache_read_input_tokens ?? 0) +
          (msg.usage.input_tokens ?? 0);
      }
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

function analyzeNumstat(file, framework) {
  const out = {
    files_changed: 0,
    loc_js_added: 0,
    loc_native_added: 0,
    loc_native_code_added: 0,
    loc_native_config_added: 0,
    loc_generated_added: 0,
  };
  if (!fs.existsSync(file)) return out;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const m = line.match(/^(\d+|-)\t(\d+|-)\t(.+)$/);
    if (!m) continue;
    out.files_changed++;
    if (m[1] === '-') continue; // binary
    const added = Number(m[1]);
    switch (classifyPath(m[3], framework)) {
      case 'native-code': out.loc_native_code_added += added; break;
      case 'native-config': out.loc_native_config_added += added; break;
      case 'generated': out.loc_generated_added += added; break;
      default: out.loc_js_added += added;
    }
  }
  // Kept so the three-way split never moves the published two-way number.
  out.loc_native_added = out.loc_native_code_added + out.loc_native_config_added;
  return out;
}

function median(xs) {
  const s = xs.filter(x => typeof x === 'number' && !Number.isNaN(x)).sort((a, b) => a - b);
  if (!s.length) return null;
  const mid = s.length >> 1;
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

function range(xs) {
  const s = xs.filter(x => typeof x === 'number' && !Number.isNaN(x)).sort((a, b) => a - b);
  return s.length ? [s[0], s[s.length - 1]] : null;
}

const NUMERIC = [
  'input', 'output', 'cache_write', 'cache_read', 'total_cost_usd', 'turns', 'wall_s',
  'mcp_docs', 'web', 'loc_js_added', 'loc_native_added',
  'loc_native_code_added', 'loc_native_config_added', 'loc_generated_added',
];
// Aggregated per phase but never summed into a per-trial total: it measures the
// size of a session's fixed context prefix, so adding three phases' worth is
// meaningless.
const PER_PHASE_ONLY = ['first_turn_context'];

// Column order is append-only: the leading columns match the v1.0 summary.csv so a
// diff against the published file shows added columns, never moved ones.
const COLS = [
  'trial', 'framework', 'model', 'phase', 'build_pass', 'capped', 'outcome', 'acceptance',
  'input', 'output', 'cache_write', 'cache_read', 'total_cost_usd', 'turns', 'wall_s',
  'reads', 'edits', 'bash', 'mcp_docs', 'web', 'tasks', 'other_tools',
  'files_changed', 'loc_js_added', 'loc_native_added',
  'study', 'set', 'spec_version', 'loc_native_code_added', 'loc_native_config_added', 'loc_generated_added',
  'first_turn_context', 'summary_usage_mismatch',
];

function analyzeStudy(study) {
  const resultsDir = path.join(ROOT, study.resultsDir);
  if (!fs.existsSync(resultsDir)) return null;

  const phaseIds = study.phases.map(p => p.id).concat('R');
  const rows = [];

  for (const trial of fs.readdirSync(resultsDir).sort()) {
    const dir = path.join(resultsDir, trial);
    const manifest = readJSON(path.join(dir, 'manifest.json'));
    if (!manifest) continue;
    const framework = getFramework(manifest.framework);
    for (const phase of phaseIds) {
      const p = manifest.phases?.[phase];
      if (!p) continue;
      const t = analyzeTranscript(path.join(dir, `phase-${phase}.jsonl`)) ?? {};
      const d = analyzeNumstat(path.join(dir, 'diffs', `phase-${phase}.numstat`), framework);
      const wall = t.first_ts && t.last_ts
        ? (new Date(t.last_ts) - new Date(t.first_ts)) / 1000
        : (p.duration_ms != null ? p.duration_ms / 1000 : null);
      const summaryOut = p.usage?.output_tokens;
      const summaryMismatch = summaryOut != null && t.output
        ? Math.abs(summaryOut - t.output) / t.output > 0.02
        : false;
      rows.push({
        trial, framework: manifest.framework, model: manifest.model, phase,
        build_pass: p.build_pass ?? null,
        capped: p.is_error ?? null,
        outcome: manifest.outcome ?? null,
        acceptance: manifest.acceptance?.status ?? null,
        input: t.input ?? null, output: t.output ?? null,
        cache_write: t.cache_write ?? null, cache_read: t.cache_read ?? null,
        // Token counts come from the transcript (PLAN §5.2 — the ground truth);
        // cost only exists in the headless summary. Those two can disagree: one
        // observed session reported 430 output tokens and num_turns 1 for a
        // 632s session the transcript shows as 14,937 tokens. When they diverge,
        // the summary's cost describes work that did not happen, so it is
        // withheld rather than published as a number that looks fine.
        total_cost_usd: summaryMismatch ? null : (p.total_cost_usd ?? null),
        summary_usage_mismatch: summaryMismatch,
        turns: p.num_turns ?? null,
        wall_s: wall != null ? Math.round(wall) : null,
        reads: t.reads ?? null, edits: t.edits ?? null, bash: t.bash ?? null,
        mcp_docs: t.mcp_docs ?? null, web: t.web ?? null, tasks: t.tasks ?? null,
        other_tools: t.other_tools ?? null,
        study: study.slug,
        set: trialSet(study, trial),
        spec_version: manifest.spec_version ?? study.specVersion,
        first_turn_context: t.first_turn_context ?? null,
        ...d,
      });
    }
  }
  if (!rows.length) return null;

  // Aggregates per trial set, so pilot calibration runs can never leak into a
  // headline median (they ran under a different turn cap).
  const sets = [...new Set(rows.map(r => r.set))];
  const aggregates = {};
  for (const set of sets) {
    aggregates[set] = {};
    const inSet = rows.filter(r => r.set === set);
    for (const fw of study.frameworks) {
      const byFw = inSet.filter(r => r.framework === fw);
      if (!byFw.length) continue;
      aggregates[set][fw] = {};
      for (const phase of [...phaseIds, 'total']) {
        const sample = phase === 'total'
          ? Object.values(Object.groupBy(byFw.filter(r => r.phase !== 'R'), r => r.trial))
              // A per-trial total is only meaningful if every phase contributed.
              // Treating a withheld value as 0 would silently understate the
              // trial and drag the median down.
              .map(trialRows => Object.fromEntries(
                NUMERIC.map(c => [
                  c,
                  trialRows.some(r => r[c] == null)
                    ? null
                    : trialRows.reduce((a, r) => a + r[c], 0),
                ]),
              ))
          : byFw.filter(r => r.phase === phase);
        if (!sample.length) continue;
        const metrics = phase === 'total' ? NUMERIC : [...NUMERIC, ...PER_PHASE_ONLY];
        aggregates[set][fw][phase === 'total' ? 'total_per_trial' : `phase_${phase}`] = {
          n: sample.length,
          ...Object.fromEntries(metrics.flatMap(c => [
            [`median_${c}`, median(sample.map(r => r[c]))],
            [`range_${c}`, range(sample.map(r => r[c]))],
          ])),
        };
      }
    }
  }

  const csv = [COLS.join(',')]
    .concat(rows.map(r => COLS.map(c => r[c] ?? '').join(',')))
    .join('\n');
  fs.writeFileSync(path.join(resultsDir, 'summary.csv'), csv + '\n');
  fs.writeFileSync(
    path.join(resultsDir, 'summary.json'),
    JSON.stringify({
      study: study.slug,
      title: study.title,
      spec_version: study.specVersion,
      frameworks: study.frameworks,
      median_set: study.medianSet ?? 'main',
      rows,
      aggregates,
    }, null, 2) + '\n',
  );
  return { study, rows, aggregates, resultsDir };
}

/* ------------------------------------------------------------------ print */

const fmt = n => n == null ? '—' : (typeof n === 'number' && !Number.isInteger(n) ? n.toFixed(2) : String(n));

const only = process.argv[2];
const slugs = only ? [only] : listStudies();
let analyzed = 0;

for (const slug of slugs) {
  const study = getStudy(slug);
  const res = analyzeStudy(study);
  if (!res) {
    if (only) console.error(`no trials found under ${study.resultsDir}`);
    continue;
  }
  analyzed++;
  const { rows, aggregates, resultsDir } = res;
  const medianSet = study.medianSet ?? 'main';

  console.log(`\n═══ ${study.title} (${study.slug}, spec ${study.specVersion}) ═══`);
  console.log('\nPer trial × phase:');
  console.log(['trial', 'fw', 'ph', 'set', 'build', 'capped', 'input', 'output', 'cache_w', 'cache_r', 'cost$', 'turns', 'wall_s', 'docs', 'loc_js', 'nat_code', 'nat_cfg'].join('\t'));
  for (const r of rows) {
    console.log([
      r.trial, r.framework, r.phase, r.set,
      r.build_pass === null ? '—' : (r.build_pass ? 'ok' : 'FAIL'),
      r.capped === null ? '—' : (r.capped ? 'YES' : 'no'),
      fmt(r.input), fmt(r.output), fmt(r.cache_write), fmt(r.cache_read), fmt(r.total_cost_usd),
      fmt(r.turns), fmt(r.wall_s), fmt(r.mcp_docs),
      fmt(r.loc_js_added), fmt(r.loc_native_code_added), fmt(r.loc_native_config_added),
    ].join('\t'));
  }

  if (aggregates[medianSet]) {
    console.log(`\nHeadline medians — trial set '${medianSet}' (other sets are in summary.json):`);
    console.log(JSON.stringify(aggregates[medianSet], null, 2));
  } else {
    console.log(`\nNo '${medianSet}' trials yet; sets present: ${Object.keys(aggregates).join(', ')}`);
  }
  console.log(`\nWrote ${path.relative(ROOT, resultsDir)}/summary.csv and summary.json`);
}

if (!analyzed) {
  console.error('no analyzable studies found');
  process.exit(1);
}
