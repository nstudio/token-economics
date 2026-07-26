import Foundation
import SparklingMethod

@objc(HealthStatusResult)
final class HealthStatusResult: SPKMethodModel {
    @objc var status: String = ""

    override class func jsonKeyPathsByPropertyKey() -> [AnyHashable: Any] {
        return ["status": "status"]
    }
}

@objc(HealthDaysResult)
final class HealthDaysResult: SPKMethodModel {
    @objc var days: [[String: Any]] = []

    override class func jsonKeyPathsByPropertyKey() -> [AnyHashable: Any] {
        return ["days": "days"]
    }
}

final class HealthGetStatusMethod: PipeMethod {
    override class func methodName() -> String { "health.getStatus" }
    override var methodName: String { "health.getStatus" }
    override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    override var resultModelClass: AnyClass { HealthStatusResult.self }

    override func call(withParamModel paramModel: Any, completionHandler: CompletionHandlerProtocol) {
        let result = HealthStatusResult()
        result.status = HealthKitManager.shared.currentStatus
        completionHandler.handleCompletion(status: .succeeded(), result: result)
    }
}

final class HealthRequestAccessMethod: PipeMethod {
    override class func methodName() -> String { "health.requestAccess" }
    override var methodName: String { "health.requestAccess" }
    override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    override var resultModelClass: AnyClass { HealthStatusResult.self }

    override func call(withParamModel paramModel: Any, completionHandler: CompletionHandlerProtocol) {
        HealthKitManager.shared.requestAccess { outcome in
            DispatchQueue.main.async {
                switch outcome {
                case .success(let status):
                    let result = HealthStatusResult()
                    result.status = status
                    completionHandler.handleCompletion(status: .succeeded(), result: result)
                case .failure(let error):
                    completionHandler.handleCompletion(status: .failed(message: error.localizedDescription), result: nil)
                }
            }
        }
    }
}

final class HealthLogStepsMethod: PipeMethod {
    override class func methodName() -> String { "health.logSteps" }
    override var methodName: String { "health.logSteps" }
    override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    override var resultModelClass: AnyClass { EmptyMethodModelClass.self }

    override func call(withParamModel paramModel: Any, completionHandler: CompletionHandlerProtocol) {
        HealthKitManager.shared.logSteps(count: 500) { error in
            DispatchQueue.main.async {
                if let error {
                    completionHandler.handleCompletion(status: .failed(message: error.localizedDescription), result: nil)
                } else {
                    completionHandler.handleCompletion(status: .succeeded(), result: nil)
                }
            }
        }
    }
}

final class HealthGetLastSevenDaysMethod: PipeMethod {
    override class func methodName() -> String { "health.getLastSevenDays" }
    override var methodName: String { "health.getLastSevenDays" }
    override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    override var resultModelClass: AnyClass { HealthDaysResult.self }

    override func call(withParamModel paramModel: Any, completionHandler: CompletionHandlerProtocol) {
        HealthKitManager.shared.lastSevenDays { outcome in
            DispatchQueue.main.async {
                switch outcome {
                case .success(let days):
                    let result = HealthDaysResult()
                    result.days = days
                    completionHandler.handleCompletion(status: .succeeded(), result: result)
                case .failure(let error):
                    completionHandler.handleCompletion(status: .failed(message: error.localizedDescription), result: nil)
                }
            }
        }
    }
}
