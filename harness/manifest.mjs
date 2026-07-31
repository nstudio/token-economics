#!/usr/bin/env node
// Content-hash manifest for a study's archived evidence.
//
// Usage:
//   node manifest.mjs <study-slug>            # write <study>/MANIFEST.sha256
//   node manifest.mjs <study-slug> --check    # verify, exit nonzero on drift
//
// Every published number traces to a transcript; this file is what proves the
// transcript hasn't changed since publication. Generated app binaries are
// excluded (they are regenerable build output, not evidence).

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { ROOT, getStudy } from './lib/registry.mjs';

const slug = process.argv[2];
const check = process.argv.includes('--check');
if (!slug) { console.error('usage: node manifest.mjs <study-slug> [--check]'); process.exit(2); }

const study = getStudy(slug);
const dir = path.join(ROOT, study.resultsDir);
if (!fs.existsSync(dir)) { console.error(`no results at ${study.resultsDir}`); process.exit(1); }

const SKIP_DIRS = new Set(['app', 'app-release']);
const MANIFEST_NAME = 'MANIFEST.sha256';

function walk(d, rel = '') {
  const out = [];
  for (const e of fs.readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    if (e.isDirectory()) {
      if (SKIP_DIRS.has(e.name)) continue;
      out.push(...walk(path.join(d, e.name), path.join(rel, e.name)));
    } else if (e.isFile() && e.name !== MANIFEST_NAME) {
      out.push(path.join(rel, e.name));
    }
  }
  return out;
}

const files = walk(dir);
const lines = files.map(f => {
  const h = crypto.createHash('sha256').update(fs.readFileSync(path.join(dir, f))).digest('hex');
  return `${h}  ${f}`;
});
const body = lines.join('\n') + '\n';
const manifestPath = path.join(dir, MANIFEST_NAME);

if (check) {
  if (!fs.existsSync(manifestPath)) { console.error(`no ${MANIFEST_NAME} in ${study.resultsDir} — generate it first`); process.exit(1); }
  const prev = fs.readFileSync(manifestPath, 'utf8');
  if (prev === body) {
    console.log(`${study.slug}: ${files.length} files verified against ${MANIFEST_NAME}`);
  } else {
    const prevMap = new Map(prev.trim().split('\n').map(l => [l.slice(66), l.slice(0, 64)]));
    const nowMap = new Map(lines.map(l => [l.slice(66), l.slice(0, 64)]));
    for (const [f, h] of nowMap) {
      if (!prevMap.has(f)) console.log(`ADDED    ${f}`);
      else if (prevMap.get(f) !== h) console.log(`CHANGED  ${f}`);
    }
    for (const f of prevMap.keys()) if (!nowMap.has(f)) console.log(`REMOVED  ${f}`);
    console.error(`\n${study.slug}: MANIFEST DRIFT`);
    process.exit(1);
  }
} else {
  fs.writeFileSync(manifestPath, body);
  console.log(`${study.slug}: wrote ${path.join(study.resultsDir, MANIFEST_NAME)} (${files.length} files)`);
}
