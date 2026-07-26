import Foundation
import Lynx

/// Native test fixture for the JS↔native interop microbenchmarks — the same
/// role as the TestFixtures class in the original NativeScript perf-metrics
/// posts. Both frameworks in the study get an equivalent fixture; what differs
/// is how JS reaches it (an authored bridge module here vs direct binding).
@objc(InteropBenchModule)
@objcMembers
public class InteropBenchModule: NSObject, LynxContextModule {
    public static var name: String { "InteropBenchModule" }

    public static var methodLookup: [String: String] {
        return [
            "add": NSStringFromSelector(#selector(add(_:b:c:callback:))),
            "strLen": NSStringFromSelector(#selector(strLen(_:callback:))),
            "sumBytes": NSStringFromSelector(#selector(sumBytes(_:callback:))),
        ]
    }

    private weak var context: LynxContext?

    public required init(lynxContext context: LynxContext) {
        self.context = context
        super.init()
    }

    public required init(lynxContext context: LynxContext, withParam param: Any) {
        self.context = context
        super.init()
    }

    public required init(param: Any) {
        super.init()
    }

    public override required init() {
        super.init()
    }

    func add(_ a: Double, b: Double, c: Double, callback: @escaping (NSNumber) -> Void) {
        callback(NSNumber(value: a + b + c))
    }

    func strLen(_ value: NSString, callback: @escaping (NSNumber) -> Void) {
        callback(NSNumber(value: value.length))
    }

    func sumBytes(_ value: NSString, callback: @escaping (NSNumber) -> Void) {
        var sum: Int64 = 0
        if let data = (value as String).data(using: .utf8) {
            data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                for byte in raw {
                    sum += Int64(byte)
                }
            }
        }
        callback(NSNumber(value: sum))
    }
}
