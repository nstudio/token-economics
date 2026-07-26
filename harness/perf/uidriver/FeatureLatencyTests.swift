import XCTest

/// Generic feature-path latency driver for the token-economics benchmark apps.
/// Operates any app whose UI follows SPEC.md's pinned labels — the app under
/// test is chosen via TARGET_BUNDLE_ID, so agent-built artifacts are never
/// modified. Emits one machine-readable line: PERFJSON:{...}
final class FeatureLatencyTests: XCTestCase {

  var runs: [[String: Any]] = []
  var dumpedTree = false

  func now() -> Double { CFAbsoluteTimeGetCurrent() }
  func step(_ s: String) { print("STEP[\(Int(now() - t0Global))s]: \(s)") }
  var t0Global: Double = 0

  func anyElement(_ app: XCUIApplication, labelBeginsWith p: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", p)).firstMatch
  }
  func anyElement(_ app: XCUIApplication, labelContains p: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", p)).firstMatch
  }
  func tappable(_ app: XCUIApplication, _ label: String) -> XCUIElement {
    let b = app.buttons[label].firstMatch
    if b.exists { return b }
    return app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
  }
  func safeLabel(_ el: XCUIElement) -> String { el.exists ? el.label : "" }
  func dumpTreeOnce(_ app: XCUIApplication, _ why: String) {
    guard !dumpedTree else { return }
    dumpedTree = true
    print("TREE(\(why)):\n" + app.debugDescription)
  }

  func goHome(_ app: XCUIApplication) -> Bool {
    let transcribe = tappable(app, "Transcribe")
    let health = tappable(app, "Health")
    if transcribe.exists && health.exists && transcribe.isHittable { return true }
    var candidates: [XCUIElement] = [
      app.navigationBars.buttons.element(boundBy: 0),
      app.buttons["Back"].firstMatch,
      app.buttons["Home"].firstMatch,
      anyElement(app, labelContains: "Back"),
    ]
    for (i, c) in candidates.enumerated() {
      if c.exists && c.isHittable {
        step("goHome: tapping candidate \(i)")
        c.tap()
        if tappable(app, "Transcribe").waitForExistence(timeout: 3) { return true }
      }
    }
    step("goHome: edge swipe fallback")
    let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
    edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
    if tappable(app, "Transcribe").waitForExistence(timeout: 3) { return true }
    dumpTreeOnce(app, "goHome failed")
    return false
  }

  func grantHealthSheet(_ app: XCUIApplication) {
    let sheetHosts: [(String, XCUIApplication)] = [
      ("app", app),
      ("springboard", XCUIApplication(bundleIdentifier: "com.apple.springboard")),
    ]
    let enableLabels = ["Turn On All", "Turn On All Categories", "Enable All"]
    let confirmLabels = ["Allow", "Done", "Turn On All"]
    for (name, host) in sheetHosts {
      for l in enableLabels {
        let e = anyElement(host, labelContains: l)
        if e.waitForExistence(timeout: 3), e.isHittable {
          step("health sheet(\(name)): tap '\(l)'")
          e.tap(); break
        }
      }
      for l in confirmLabels {
        let e = host.buttons[l].firstMatch
        if e.waitForExistence(timeout: 2), e.isHittable {
          step("health sheet(\(name)): confirm '\(l)'")
          e.tap(); return
        }
      }
    }
    step("health sheet: no sheet controls found (may already be granted)")
  }

  func grantSystemAlert() {
    let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    for l in ["Allow", "OK"] {
      let b = sb.alerts.buttons[l].firstMatch
      if b.waitForExistence(timeout: 3) { step("system alert: '\(l)'"); b.tap(); return }
    }
    step("system alert: none appeared")
  }

  func testFeatureLatencies() throws {
    continueAfterFailure = true
    t0Global = now()
    let env = ProcessInfo.processInfo.environment
    guard let bid = env["TARGET_BUNDLE_ID"] else { XCTFail("TARGET_BUNDLE_ID not set"); return }
    let iters = Int(env["ITERS"] ?? "3") ?? 3
    addUIInterruptionMonitor(withDescription: "perm") { alert in
      for l in ["Allow", "OK"] where alert.buttons[l].exists { alert.buttons[l].tap(); return true }
      return false
    }

    defer {
      let payload: [String: Any] = ["bundle_id": bid, "runs": runs]
      if let data = try? JSONSerialization.data(withJSONObject: payload),
         let s = String(data: data, encoding: .utf8) {
        print("PERFJSON:" + s)
      }
    }

    for i in 0..<iters {
      var run: [String: Any] = ["iter": i]
      step("iter \(i): launch \(bid)")
      let app = XCUIApplication(bundleIdentifier: bid)
      app.launch()
      guard tappable(app, "Health").waitForExistence(timeout: 20) else {
        dumpTreeOnce(app, "home not visible")
        run["error"] = "home not visible"; runs.append(run); continue
      }

      // — nav → Health, status line render
      step("iter \(i): nav Health")
      var t0 = now()
      tappable(app, "Health").tap()
      let healthStatus = anyElement(app, labelBeginsWith: "Health access")
      if healthStatus.waitForExistence(timeout: 10) {
        run["nav_health_ms"] = Int((now() - t0) * 1000)
      } else {
        dumpTreeOnce(app, "no Health status line")
        run["error_nav_health"] = true
      }

      if safeLabel(healthStatus).contains("not requested") {
        step("iter \(i): HK authorize")
        let req = tappable(app, "Request Access")
        if req.exists && req.isHittable {
          req.tap()
          grantHealthSheet(app)
          _ = anyElement(app, labelBeginsWith: "Health access: granted").waitForExistence(timeout: 15)
        }
      }
      run["health_granted"] = safeLabel(healthStatus).contains("granted")

      // — 7-day rows (query + marshal + render)
      t0 = now()
      let row = anyElement(app, labelContains: " steps")
      if row.waitForExistence(timeout: 15) { run["hk_rows_ms"] = Int((now() - t0) * 1000) }

      // — log 500 steps → today row updates
      let today = anyElement(app, labelContains: "(today)")
      let before = safeLabel(today)
      let logBtn = tappable(app, "Log 500 Steps")
      if logBtn.exists && logBtn.isHittable {
        step("iter \(i): log 500")
        t0 = now()
        logBtn.tap()
        let deadline = now() + 15
        var changed = false
        while now() < deadline {
          if safeLabel(today) != before && today.exists { changed = true; break }
          usleep(50_000)
        }
        if changed { run["hk_log_roundtrip_ms"] = Int((now() - t0) * 1000) }
        else { run["error_hk_log"] = true }
      }

      // — back home, nav → Transcribe
      step("iter \(i): go home")
      if !goHome(app) { run["error"] = "goHome failed"; runs.append(run); app.terminate(); continue }
      step("iter \(i): nav Transcribe")
      t0 = now()
      tappable(app, "Transcribe").tap()
      let speechStatus = anyElement(app, labelBeginsWith: "Speech access")
      if speechStatus.waitForExistence(timeout: 10) {
        run["nav_transcribe_ms"] = Int((now() - t0) * 1000)
      } else {
        dumpTreeOnce(app, "no Speech status line")
        run["error_nav_transcribe"] = true
      }

      if safeLabel(speechStatus).contains("not requested") {
        step("iter \(i): speech authorize")
        let req = tappable(app, "Request Access")
        if req.exists && req.isHittable {
          req.tap()
          grantSystemAlert()
          _ = anyElement(app, labelBeginsWith: "Speech access: granted").waitForExistence(timeout: 15)
        }
      }
      run["speech_granted"] = safeLabel(speechStatus).contains("granted")

      // — transcription: tap → "Completed in N.N s". Server-based recognition
      // rides Siri infrastructure that simulators lack, so a hang here is an
      // environment limit, not an app defect — record the state either way.
      let speechTimeout = Double(env["SPEECH_TIMEOUT"] ?? "45") ?? 45
      let trBtn = tappable(app, "Transcribe Sample")
      if trBtn.exists && trBtn.isHittable {
        step("iter \(i): transcribe")
        t0 = now()
        trBtn.tap()
        let done = anyElement(app, labelBeginsWith: "Completed in")
        if done.waitForExistence(timeout: speechTimeout) {
          run["speech_wall_ms"] = Int((now() - t0) * 1000)
          run["speech_state"] = "completed"
          let lbl = safeLabel(done)
          if let r = lbl.range(of: #"[0-9]+(\.[0-9]+)?"#, options: .regularExpression) {
            run["speech_app_reported_s"] = Double(lbl[r]) ?? -1
          }
        } else {
          let transcribing = anyElement(app, labelContains: "Transcribing")
          let failed = anyElement(app, labelContains: "Fail")
          run["speech_state"] = transcribing.exists ? "hung_transcribing"
            : failed.exists ? "init_or_task_failed: \(safeLabel(failed))"
            : "unknown: \(safeLabel(anyElement(app, labelBeginsWith: "Speech")))"
        }
      } else if speechStatus.exists {
        run["speech_state"] = "button_unavailable"
      }

      step("iter \(i): done")
      app.terminate()
      runs.append(run)
    }
  }
}
