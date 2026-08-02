#!/usr/bin/env node
// Framework + study registry. Single source of truth for every runner and analyzer:
// adding a framework or a study means adding a JSON file here, never editing a case
// statement. Also owns LOC classification, so `run-trial.sh` and `analyze.mjs` can
// never disagree about what counts as native.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const HARNESS = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
export const ROOT = path.dirname(HARNESS);

function readJSON(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function listIds(dir) {
  const d = path.join(HARNESS, dir);
  return fs.existsSync(d)
    ? fs.readdirSync(d).filter(f => f.endsWith('.json')).map(f => f.slice(0, -5)).sort()
    : [];
}

export const listFrameworks = () => listIds('frameworks');
export const listStudies = () => listIds('studies');

export function getFramework(id) {
  const file = path.join(HARNESS, 'frameworks', `${id}.json`);
  if (!fs.existsSync(file)) {
    throw new Error(`unknown framework '${id}' (have: ${listFrameworks().join(', ')})`);
  }
  return readJSON(file);
}

export function getStudy(slug) {
  const file = path.join(HARNESS, 'studies', `${slug}.json`);
  if (!fs.existsSync(file)) {
    throw new Error(`unknown study '${slug}' (have: ${listStudies().join(', ')})`);
  }
  const study = readJSON(file);
  for (const fw of study.frameworks) getFramework(fw); // fail fast on a dangling reference
  return study;
}

/** The study a trial directory belongs to, or null — used to scope analysis. */
export function studyOfFramework(fw) {
  return listStudies().map(getStudy).filter(s => s.frameworks.includes(fw));
}

/** Which named trial set (pilot/main/…) a trial id falls into, per the study's patterns. */
export function trialSet(study, trialId) {
  for (const [name, pattern] of Object.entries(study.trialSets ?? {})) {
    if (new RegExp(pattern).test(trialId)) return name;
  }
  return 'other';
}

/* ------------------------------------------------------------------ */
/* LOC classification                                                  */
/* ------------------------------------------------------------------ */

// Source files in a native language.
const NATIVE_CODE_EXTS = new Set(['swift', 'h', 'm', 'mm', 'kt', 'java']);
// Native project/build/permission configuration — not written in a native language,
// but it is native-side work (entitlements, usage strings, build settings, podspecs).
const NATIVE_CONFIG_EXTS = new Set([
  'plist', 'entitlements', 'xcconfig', 'pbxproj', 'storyboard',
  'modulemap', 'podspec', 'xcscheme',
]);

// Machine-generated dependency manifests. A resolver writes these; nobody
// authors them, and their churn is proportional to how many packages a
// framework's idiom pulls in — counting them as written code would credit
// `npm install` as authorship.
const GENERATED_FILES =
  /(^|\/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|npm-shrinkwrap\.json|Podfile\.lock|Gemfile\.lock|bun\.lockb)$/;

/**
 * Classify a repo-relative path as
 * 'native-code' | 'native-config' | 'js' | 'generated'.
 *
 * Invariant relied on by the published v1.0 numbers: the union of the two native
 * buckets is exactly the old single native bucket, so `loc_native_added` is
 * unchanged. Any new rule must widen both partitions together or neither.
 *
 * 'generated' is reported separately rather than folded into any bucket, so it
 * is visible without being counted as authored work.
 */
export function classifyPath(p, framework = {}) {
  const ext = (p.split('.').pop() || '').toLowerCase();
  const base = p.split('/').pop();
  const underRoot = roots => (roots ?? []).some(r => p.startsWith(r));

  if (GENERATED_FILES.test(p)) return 'generated';
  if (NATIVE_CODE_EXTS.has(ext)) return 'native-code';
  if (NATIVE_CONFIG_EXTS.has(ext)) return 'native-config';
  if ((framework.nativeConfigFiles ?? []).includes(base)) return 'native-config';
  if (underRoot(framework.nativeConfigRoots)) return 'native-config';
  // A file under a native root with no native extension is project scaffolding
  // (Podfile, xcworkspace metadata, …) — native-side, but configuration.
  if (underRoot(framework.nativeRoots)) return 'native-config';
  return 'js';
}

/* ------------------------------------------------------------------ */
/* CLI                                                                 */
/* ------------------------------------------------------------------ */

function shellQuote(v) {
  return `'${String(v).replaceAll("'", `'\\''`)}'`;
}

function resolve(studySlug, frameworkId) {
  const study = getStudy(studySlug);
  if (!study.frameworks.includes(frameworkId)) {
    throw new Error(
      `framework '${frameworkId}' is not part of study '${studySlug}' (${study.frameworks.join(', ')})`,
    );
  }
  const fw = getFramework(frameworkId);
  return {
    study,
    framework: fw,
    repoPath: path.join(ROOT, fw.repo),
    resultsPath: path.join(ROOT, study.resultsDir),
    mcpConfigPath: path.join(HARNESS, fw.mcpConfig),
    specPath: path.join(HARNESS, study.specDir),
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [cmd, ...rest] = process.argv.slice(2);
  try {
    switch (cmd) {
      case 'list-frameworks': console.log(listFrameworks().join('\n')); break;
      case 'list-studies': console.log(listStudies().join('\n')); break;
      case 'framework': console.log(JSON.stringify(getFramework(rest[0]), null, 2)); break;
      case 'study': console.log(JSON.stringify(getStudy(rest[0]), null, 2)); break;
      case 'resolve': console.log(JSON.stringify(resolve(rest[0], rest[1]), null, 2)); break;
      case 'sh': {
        const r = resolve(rest[0], rest[1]);
        const out = {
          STUDY_SLUG: r.study.slug,
          STUDY_TITLE: r.study.title,
          STUDY_FROZEN: r.study.frozen ? '1' : '0',
          STUDY_FROZEN_REASON: r.study.frozenReason ?? '',
          SPEC_VERSION: r.study.specVersion,
          SPEC_DIR: r.specPath,
          BASELINE_TAG: r.study.baselineTag,
          STUDY_MODEL: r.study.model,
          STUDY_MAX_TURNS: String(r.study.maxTurns),
          PHASE_IDS: r.study.phases.map(p => p.id).join(' '),
          REMEDIATION_PROMPT: path.join(HARNESS, r.study.remediationPrompt),
          PROMPT_SUFFIX: r.study.promptSuffix ?? "",
          FRAMEWORK: r.framework.id,
          FRAMEWORK_LABEL: r.framework.label,
          DOCS_MCP_NAME: r.framework.docsMcpName,
          BUILD_GATE: r.framework.buildGate,
          REPO: r.repoPath,
          RESULTS_DIR: r.resultsPath,
          MCP_CONFIG: r.mcpConfigPath,
          DOCS_MCP_VERSION: r.framework.docsMcpVersion ?? '',
          DOCS_MCP_KIND: r.framework.docsMcpKind ?? 'tools',
        };
        // Exported, not merely assigned: render_prompt and record_toolchain read
        // several of these out of the environment in node child processes.
        for (const [k, v] of Object.entries(out)) console.log(`export ${k}=${shellQuote(v)}`);
        for (const p of r.study.phases) {
          console.log(`export PHASE_PROMPT_${p.id}=${shellQuote(path.join(HARNESS, p.prompt))}`);
          console.log(`export PHASE_LABEL_${p.id}=${shellQuote(p.label)}`);
        }
        break;
      }
      case 'sh-study': {
        const s = getStudy(rest[0]);
        const out = {
          STUDY_SLUG: s.slug,
          STUDY_TITLE: s.title,
          STUDY_FRAMEWORKS: s.frameworks.join(' '),
          STUDY_FROZEN: s.frozen ? '1' : '0',
          RESULTS_DIR: path.join(ROOT, s.resultsDir),
          PERF_DIR: path.join(ROOT, s.resultsDir, 'perf'),
          SPEC_DIR: path.join(HARNESS, s.specDir),
          SPEC_VERSION: s.specVersion,
          BASELINE_TAG: s.baselineTag,
        };
        for (const [k, v] of Object.entries(out)) console.log(`export ${k}=${shellQuote(v)}`);
        break;
      }
      case 'app-locator': {
        const fw = getFramework(rest[0]);
        const byConfig = {
          release: fw.releaseAppLocator,
          device: fw.deviceAppLocator,
        };
        console.log(JSON.stringify(byConfig[rest[1]] ?? fw.appLocator ?? null));
        break;
      }
      case 'get': {
        // get <framework> <field> — scalar lookups for shell callers.
        const fw = getFramework(rest[0]);
        const v = fw[rest[1]];
        if (v === undefined) throw new Error(`framework '${rest[0]}' has no field '${rest[1]}'`);
        console.log(typeof v === 'string' ? v : JSON.stringify(v));
        break;
      }
      case 'repo': {
        console.log(path.join(ROOT, getFramework(rest[0]).repo));
        break;
      }
      default:
        console.error(
          'usage: registry.mjs <list-frameworks|list-studies|framework ID|study SLUG|resolve STUDY FW|sh STUDY FW|app-locator FW>',
        );
        process.exit(2);
    }
  } catch (e) {
    console.error(`registry: ${e.message}`);
    process.exit(1);
  }
}
