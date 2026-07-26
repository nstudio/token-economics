declare const InteropFixture: {
  addABC(a: number, b: number, c: number): number
  strLen(value: string): number
  sumBytes(value: string): number
}

export type ScenarioResult = {
  id: string
  ms: number
  ops: number
  perOpUs: number | null
  check: number
}

const SMALL_STRING = 'x'.repeat(100)
const BIG_STRING = 'a'.repeat(1024 * 1024)

function finish(id: string, start: number, ops: number, check: number, perOp = true): ScenarioResult {
  const ms = Date.now() - start
  return { id, ms, ops, perOpUs: perOp ? Math.round((ms * 1000) / ops) : null, check }
}

function jsCompute(): ScenarioResult {
  const start = Date.now()
  let x = 0
  for (let i = 0; i < 2_000_000; i++) {
    x += Math.sqrt(i % 1000) * 1.000001
  }
  return finish('js_compute', start, 2_000_000, Math.round(x) % 1000, false)
}

function jsonRoundtrip(): ScenarioResult {
  const obj: Record<string, number> = {}
  for (let i = 0; i < 100; i++) obj[`k${i}`] = i
  const start = Date.now()
  let acc = 0
  for (let i = 0; i < 500; i++) {
    const parsed = JSON.parse(JSON.stringify(obj)) as Record<string, number>
    acc += parsed.k42
  }
  return finish('json_roundtrip', start, 500, acc, false)
}

function primLatency(): ScenarioResult {
  const start = Date.now()
  let acc = 0
  for (let i = 0; i < 1000; i++) {
    acc += InteropFixture.addABC(i, 2, 3)
  }
  return finish('prim_latency', start, 1000, Math.round(acc) % 1000)
}

function strLatency(): ScenarioResult {
  const start = Date.now()
  let acc = 0
  for (let i = 0; i < 1000; i++) {
    acc += InteropFixture.strLen(SMALL_STRING)
  }
  return finish('str_latency', start, 1000, acc % 1000)
}

function primBurst(): ScenarioResult {
  const start = Date.now()
  let acc = 0
  for (let i = 0; i < 10_000; i++) {
    acc += InteropFixture.addABC(i, 1, 1)
  }
  return finish('prim_burst', start, 10_000, Math.round(acc) % 1000)
}

function marshal1mb(): ScenarioResult {
  const start = Date.now()
  let acc = 0
  for (let i = 0; i < 5; i++) {
    acc += InteropFixture.strLen(BIG_STRING)
  }
  return finish('marshal_1mb', start, 5, acc % 1000)
}

function checksumJs(): ScenarioResult {
  const start = Date.now()
  let sum = 0
  for (let iter = 0; iter < 3; iter++) {
    for (let i = 0; i < BIG_STRING.length; i++) {
      sum += BIG_STRING.charCodeAt(i)
    }
  }
  return finish('checksum_js', start, 3, sum % 1000, false)
}

function checksumNative(): ScenarioResult {
  const start = Date.now()
  let sum = 0
  for (let iter = 0; iter < 3; iter++) {
    sum += InteropFixture.sumBytes(BIG_STRING)
  }
  return finish('checksum_native', start, 3, sum % 1000, false)
}

export async function runAll(onProgress: (id: string) => void): Promise<string> {
  const scenarios: Array<() => ScenarioResult> = [
    jsCompute,
    jsonRoundtrip,
    primLatency,
    strLatency,
    primBurst,
    marshal1mb,
    checksumJs,
    checksumNative,
  ]
  const results: Array<ScenarioResult> = []
  for (const scenario of scenarios) {
    const result = scenario()
    results.push(result)
    onProgress(result.id)
    // yield the runloop between scenarios so the UI stays alive
    await new Promise((resolve) => setTimeout(resolve, 50))
  }
  return `INTEROPJSON:${JSON.stringify({ fw: 'nativescript', engine: 'v8', r: results })}`
}
