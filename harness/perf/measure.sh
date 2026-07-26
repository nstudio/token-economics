#!/usr/bin/env bash
set -uo pipefail

# Runtime performance measurement over the Release .apps (see build-release.sh).
# For each trial app on one fixed simulator:
#   - size: bundle total, executable, per-framework breakdown, installed size
#   - N cold launches: T0(before simctl launch) → SpringBoard/FrontBoard launch
#     markers from `log stream`, plus process CPU-settle fallback
#   - idle steady state: RSS + phys footprint + %CPU sampled after settle
# Emits one JSON per trial into results/perf/<id>.json. Interleave-friendly:
# pass trial ids in the order you want them measured.
#
# Env: SIM_UDID (required), LAUNCHES (default 5), SETTLE_S (default 12)

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(dirname "$HARNESS_DIR")"
RESULTS_DIR="$ROOT_DIR/results"
PERF_DIR="$RESULTS_DIR/perf"
LAUNCHES="${LAUNCHES:-5}"
SETTLE_S="${SETTLE_S:-12}"
SIM_UDID="${SIM_UDID:?set SIM_UDID to the simulator UDID to measure on}"

die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "==> $*"; }
mkdir -p "$PERF_DIR"

bundle_id_of() { plutil -extract CFBundleIdentifier raw "$1/Info.plist"; }

measure_one() { # measure_one <trial-id>
  local id="$1"
  local app_dir
  app_dir="$(ls -d "$RESULTS_DIR/$id/app-release"/*.app 2>/dev/null | head -1)"
  [ -n "$app_dir" ] || die "$id: no app-release bundle (run build-release.sh)"
  local bid exe
  bid="$(bundle_id_of "$app_dir")"
  exe="$app_dir/$(plutil -extract CFBundleExecutable raw "$app_dir/Info.plist")"
  local out="$PERF_DIR/$id.json"
  note "$id ($bid): measuring"

  # ---- size ----
  local size_json
  size_json="$(node -e '
    const { execSync } = require("child_process"), fs = require("fs");
    const [app, exe] = process.argv.slice(1);
    const du = p => Number(execSync(`du -sk "${p}"`).toString().split("\t")[0]) * 1024;
    const fw = {};
    const fwDir = app + "/Frameworks";
    if (fs.existsSync(fwDir)) for (const f of fs.readdirSync(fwDir)) fw[f] = du(fwDir + "/" + f);
    console.log(JSON.stringify({ bundle_bytes: du(app), executable_bytes: du(exe), frameworks: fw }));
  ' "$app_dir" "$exe")"

  xcrun simctl uninstall "$SIM_UDID" "$bid" >/dev/null 2>&1
  xcrun simctl install "$SIM_UDID" "$app_dir" || die "$id: install failed"
  local container installed_bytes
  container="$(xcrun simctl get_app_container "$SIM_UDID" "$bid" app 2>/dev/null)"
  installed_bytes=$(( $(du -sk "$container" | cut -f1) * 1024 ))

  # ---- launches ----
  local launches="[]"
  for i in $(seq 1 "$LAUNCHES"); do
    xcrun simctl terminate "$SIM_UDID" "$bid" >/dev/null 2>&1
    sleep 3
    local logf="$PERF_DIR/.launchlog.$$"
    xcrun simctl spawn "$SIM_UDID" log stream --style ndjson \
      --predicate "(process == \"SpringBoard\" OR process == \"FrontBoard\" OR process == \"runningboardd\") AND (eventMessage CONTAINS \"$bid\")" \
      >"$logf" 2>/dev/null &
    local logpid=$!
    sleep 2
    local t0 t_ret pid
    t0="$(node -e 'console.log(Date.now())')"
    pid="$(xcrun simctl launch "$SIM_UDID" "$bid" 2>/dev/null | awk -F': ' '{print $2}')"
    t_ret="$(node -e 'console.log(Date.now())')"
    # CPU-settle watch: sample %cpu every 100ms until 6 consecutive samples < 5%
    local settle_ms
    settle_ms="$(node -e '
      const { execSync } = require("child_process");
      const [pid, t0] = process.argv.slice(1);
      const t0n = Number(t0); let quiet = 0;
      const deadline = Date.now() + 30000;
      (function poll() {
        let cpu = 999;
        try { cpu = parseFloat(execSync(`ps -o %cpu= -p ${pid}`).toString().trim()); } catch (e) {}
        if (cpu < 5) quiet++; else quiet = 0;
        if (quiet >= 6 || Date.now() > deadline) { console.log(Date.now() - 600 - t0n); return; }
        setTimeout(poll, 100);
      })();
    ' "$pid" "$t0")"
    sleep 2
    kill "$logpid" 2>/dev/null; wait "$logpid" 2>/dev/null
    launches="$(node -e '
      const fs = require("fs");
      const [prev, logf, t0, tret, settle, pid] = process.argv.slice(1);
      const arr = JSON.parse(prev);
      const entry = { t0: Number(t0), simctl_return_ms: Number(tret) - Number(t0), cpu_settle_ms: Number(settle), pid: Number(pid), markers: {} };
      try {
        for (const line of fs.readFileSync(logf, "utf8").split("\n")) {
          if (!line.trim()) continue;
          let e; try { e = JSON.parse(line); } catch (err) { continue; }
          const ts = Date.parse(e.timestamp); if (!ts || ts < entry.t0 - 500) continue;
          const m = e.eventMessage || "";
          const tag =
            /Bootstrapping request|Now tracking process/.test(m) ? "bootstrap" :
            /Launch successful|launch transaction.*complet/i.test(m) ? "launch_done" :
            /foreground-active|Running-Active|didActivate/i.test(m) ? "active" : null;
          if (tag && entry.markers[tag] === undefined) entry.markers[tag] = ts - entry.t0;
        }
      } catch (err) {}
      arr.push(entry);
      console.log(JSON.stringify(arr));
    ' "$launches" "$logf" "$t0" "$t_ret" "$settle_ms" "$pid")"
    rm -f "$logf"
    # idle steady-state on the last launch
    if [ "$i" = "$LAUNCHES" ]; then
      sleep "$SETTLE_S"
      IDLE_JSON="$(node -e '
        const { execSync } = require("child_process");
        const pid = process.argv[1];
        const samp = [];
        for (let i = 0; i < 10; i++) {
          try {
            const [rss, cpu] = execSync(`ps -o rss=,%cpu= -p ${pid}`).toString().trim().split(/\s+/);
            samp.push({ rss_kb: Number(rss), cpu: parseFloat(cpu) });
          } catch (e) {}
          execSync("sleep 1");
        }
        let foot = null;
        try {
          const f = execSync(`footprint ${pid} 2>/dev/null`).toString();
          const m = f.match(/phys_footprint:\s*([\d.]+)\s*(KB|MB|GB)/i);
          if (m) foot = Math.round(parseFloat(m[1]) * ({KB:1,MB:1024,GB:1048576})[m[2].toUpperCase()]);
        } catch (e) {}
        const med = a => { const s=[...a].sort((x,y)=>x-y); return s[s.length>>1]; };
        console.log(JSON.stringify({
          rss_kb_median: med(samp.map(s=>s.rss_kb)), cpu_pct_median: med(samp.map(s=>s.cpu)),
          cpu_pct_max: Math.max(...samp.map(s=>s.cpu)), phys_footprint_kb: foot, samples: samp.length
        }));
      ' "$pid")"
    fi
    xcrun simctl terminate "$SIM_UDID" "$bid" >/dev/null 2>&1
  done

  node -e '
    const fs = require("fs");
    const [out, id, bid, size, installed, launches, idle, sim, n] = process.argv.slice(1);
    fs.writeFileSync(out, JSON.stringify({
      trial: id, bundle_id: bid, sim_udid: sim, launches_n: Number(n),
      measured_at: new Date().toISOString(),
      size: { ...JSON.parse(size), installed_bytes: Number(installed) },
      launches: JSON.parse(launches),
      idle: JSON.parse(idle),
    }, null, 2));
  ' "$out" "$id" "$bid" "$size_json" "$installed_bytes" "$launches" "$IDLE_JSON" "$SIM_UDID" "$LAUNCHES"
  note "$id: wrote perf/$id.json"
}

TRIALS="${*:-main-ns-1 main-lynx-1 main-ns-2 main-lynx-2 main-ns-3 main-lynx-3 main-ns-4 main-lynx-4 main-ns-5 main-lynx-5}"
for id in $TRIALS; do measure_one "$id"; done
note "measurement complete"
