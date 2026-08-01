#!/usr/bin/env bash
set -uo pipefail

# Operator acceptance helper (SPEC.md §6).
#
#   ./acceptance.sh <study> list                 # trials and their acceptance status
#   ./acceptance.sh <study> install <trial-id>   # install + launch that trial's archived app
#   ./acceptance.sh <study> pass <trial-id> [note]
#   ./acceptance.sh <study> fail <trial-id> "<what failed>"
#
# The build gate proves an app COMPILES. Acceptance proves it WORKS — permission
# flows, data persistence, streaming transcription, and deny paths. Nothing is
# published as a success rate until this runs.
#
# Env: SIM_UDID (defaults to the booted simulator)

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HARNESS_DIR/lib/common.sh"

STUDY="${1:-}"; ACTION="${2:-list}"; TRIAL="${3:-}"; NOTE="${4:-}"
te_resolve_study "$STUDY"

sim_udid() {
  if [ -n "${SIM_UDID:-}" ]; then echo "$SIM_UDID"; return; fi
  xcrun simctl list devices booted 2>/dev/null | grep -oE '[0-9A-F-]{36}' | head -1
}

case "$ACTION" in
  list)
    node -e '
      const fs = require("fs"), path = require("path");
      const dir = process.argv[1];
      const rows = [];
      for (const t of fs.readdirSync(dir).sort()) {
        const mf = path.join(dir, t, "manifest.json");
        if (!fs.existsSync(mf)) continue;
        const m = JSON.parse(fs.readFileSync(mf, "utf8"));
        // Not acceptance candidates: attempts that spent zero measured tokens,
        // and runs replaced by a later one.
        if (t.includes("infra-invalid") || m.infra_invalid) continue;
        if (m.superseded) continue;
        rows.push({
          trial: t,
          fw: m.framework,
          status: m.acceptance?.status ?? "pending",
          note: m.acceptance?.notes || (fs.existsSync(path.join(dir, t, "app")) ? "" : "no archived app"),
        });
      }
      const w = Math.max(5, ...rows.map(r => r.trial.length)) + 2;
      console.log("TRIAL".padEnd(w) + "FW".padEnd(7) + "STATUS".padEnd(10) + "NOTES");
      for (const r of rows) {
        console.log(r.trial.padEnd(w) + r.fw.padEnd(7) + r.status.padEnd(10) + r.note);
      }
      const pend = rows.filter(r => r.status === "pending").length;
      console.log(`\n${rows.length} acceptance candidates, ${pend} pending`);
    ' "$RESULTS_DIR"
    ;;

  install)
    [ -n "$TRIAL" ] || te_die "usage: acceptance.sh <study> install <trial-id>"
    udid="$(sim_udid)"; [ -n "$udid" ] || te_die "no booted simulator (boot one, or set SIM_UDID)"
    app="$(ls -d "$RESULTS_DIR/$TRIAL/app"/*.app 2>/dev/null | head -1)"
    [ -n "$app" ] || te_die "no archived app at $RESULTS_DIR/$TRIAL/app"
    bid="$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")"
    te_note "uninstalling any previous copy (acceptance needs a clean permission state)"
    xcrun simctl uninstall "$udid" "$bid" >/dev/null 2>&1
    xcrun simctl install "$udid" "$app" || te_die "install failed"
    xcrun simctl launch "$udid" "$bid" >/dev/null || te_die "launch failed"
    open -a Simulator
    te_note "$TRIAL ($bid) installed and launched — run the SPEC §6 checklist"
    ;;

  pass|fail)
    [ -n "$TRIAL" ] || te_die "usage: acceptance.sh <study> $ACTION <trial-id> [note]"
    mf="$RESULTS_DIR/$TRIAL/manifest.json"
    [ -f "$mf" ] || te_die "no manifest at $mf"
    ACTION="$ACTION" NOTE="$NOTE" node -e '
      const fs = require("fs");
      const f = process.argv[1];
      const m = JSON.parse(fs.readFileSync(f, "utf8"));
      m.acceptance = {
        status: process.env.ACTION === "pass" ? "pass" : "fail",
        items: m.acceptance?.items ?? {},
        notes: process.env.NOTE || "",
        recorded_at: new Date().toISOString().slice(0, 10),
      };
      if (process.env.ACTION === "pass") m.outcome = "accepted";
      fs.writeFileSync(f, JSON.stringify(m, null, 2));
    ' "$mf"
    te_note "$TRIAL recorded as $ACTION"
    [ "$ACTION" = "fail" ] && te_note "one remediation round is allowed (tokens counted):
  ./run-trial.sh remediate $TRIAL \"$NOTE\""
    ;;

  *) te_die "unknown action '$ACTION' (list | install | pass | fail)" ;;
esac
