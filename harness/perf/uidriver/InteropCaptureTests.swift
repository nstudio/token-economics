import XCTest

/// Launches the interop-bench build of TARGET_BUNDLE_ID and captures the
/// app-reported results: the page renders a text element whose accessibility
/// label starts with "INTEROPJSON:". Timing happens inside the app; this test
/// only collects.
final class InteropCaptureTests: XCTestCase {

  func testCaptureInteropResults() throws {
    let env = ProcessInfo.processInfo.environment
    guard let bid = env["TARGET_BUNDLE_ID"] else { XCTFail("TARGET_BUNDLE_ID not set"); return }
    let timeout = Double(env["INTEROP_TIMEOUT"] ?? "240") ?? 240

    let app = XCUIApplication(bundleIdentifier: bid)
    app.launch()

    let result = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label BEGINSWITH %@", "INTEROPJSON:"))
      .firstMatch
    guard result.waitForExistence(timeout: timeout) else {
      let done = app.descendants(matching: .any)
        .matching(NSPredicate(format: "label CONTAINS %@", "running"))
        .firstMatch
      XCTFail("no INTEROPJSON element within \(Int(timeout))s; last status: \(done.exists ? done.label : "unknown")")
      return
    }
    print("INTEROP_RESULT_BEGIN")
    print(result.label)
    print("INTEROP_RESULT_END")
    app.terminate()
  }
}
