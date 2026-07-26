export type ScenarioResult = {
  id: string;
  ms: number;
  ops: number;
  perOpUs: number | null;
  check: number;
};

const SMALL_STRING = 'x'.repeat(100);
const BIG_STRING = 'a'.repeat(1024 * 1024);

const bench = () => NativeModules.InteropBenchModule;

const add = (a: number, b: number, c: number) =>
  new Promise<number>((resolve) => bench().add(a, b, c, (v) => resolve(Number(v))));
const strLen = (s: string) =>
  new Promise<number>((resolve) => bench().strLen(s, (v) => resolve(Number(v))));
const sumBytes = (s: string) =>
  new Promise<number>((resolve) => bench().sumBytes(s, (v) => resolve(Number(v))));

function finish(id: string, start: number, ops: number, check: number, perOp = true): ScenarioResult {
  const ms = Date.now() - start;
  return { id, ms, ops, perOpUs: perOp ? Math.round((ms * 1000) / ops) : null, check };
}

function jsCompute(): ScenarioResult {
  const start = Date.now();
  let x = 0;
  for (let i = 0; i < 2_000_000; i++) {
    x += Math.sqrt(i % 1000) * 1.000001;
  }
  return finish('js_compute', start, 2_000_000, Math.round(x) % 1000, false);
}

function jsonRoundtrip(): ScenarioResult {
  const obj: Record<string, number> = {};
  for (let i = 0; i < 100; i++) obj[`k${i}`] = i;
  const start = Date.now();
  let acc = 0;
  for (let i = 0; i < 500; i++) {
    const parsed = JSON.parse(JSON.stringify(obj)) as Record<string, number>;
    acc += parsed.k42;
  }
  return finish('json_roundtrip', start, 500, acc, false);
}

async function primLatency(): Promise<ScenarioResult> {
  const start = Date.now();
  let acc = 0;
  for (let i = 0; i < 1000; i++) {
    acc += await add(i, 2, 3);
  }
  return finish('prim_latency', start, 1000, Math.round(acc) % 1000);
}

async function strLatency(): Promise<ScenarioResult> {
  const start = Date.now();
  let acc = 0;
  for (let i = 0; i < 1000; i++) {
    acc += await strLen(SMALL_STRING);
  }
  return finish('str_latency', start, 1000, acc % 1000);
}

async function primBurst(): Promise<ScenarioResult> {
  const start = Date.now();
  const pending: Promise<number>[] = [];
  for (let i = 0; i < 10_000; i++) {
    pending.push(add(i, 1, 1));
  }
  const values = await Promise.all(pending);
  let acc = 0;
  for (const v of values) acc += v;
  return finish('prim_burst', start, 10_000, Math.round(acc) % 1000);
}

async function marshal1mb(): Promise<ScenarioResult> {
  const start = Date.now();
  let acc = 0;
  for (let i = 0; i < 5; i++) {
    acc += await strLen(BIG_STRING);
  }
  return finish('marshal_1mb', start, 5, acc % 1000);
}

function checksumJs(): ScenarioResult {
  const start = Date.now();
  let sum = 0;
  for (let iter = 0; iter < 3; iter++) {
    for (let i = 0; i < BIG_STRING.length; i++) {
      sum += BIG_STRING.charCodeAt(i);
    }
  }
  return finish('checksum_js', start, 3, sum % 1000, false);
}

async function checksumNative(): Promise<ScenarioResult> {
  const start = Date.now();
  let sum = 0;
  for (let iter = 0; iter < 3; iter++) {
    sum += await sumBytes(BIG_STRING);
  }
  return finish('checksum_native', start, 3, sum % 1000, false);
}

export async function runAll(onProgress: (id: string) => void): Promise<string> {
  const scenarios: Array<() => ScenarioResult | Promise<ScenarioResult>> = [
    jsCompute,
    jsonRoundtrip,
    primLatency,
    strLatency,
    primBurst,
    marshal1mb,
    checksumJs,
    checksumNative,
  ];
  const results: ScenarioResult[] = [];
  for (const scenario of scenarios) {
    const result = await scenario();
    results.push(result);
    onProgress(result.id);
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  return `INTEROPJSON:${JSON.stringify({ fw: 'lynxjs', engine: 'primjs', r: results })}`;
}
