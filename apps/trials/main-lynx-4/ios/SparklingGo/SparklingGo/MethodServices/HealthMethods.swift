// Copyright 2025 The Sparkling Authors. All rights reserved.
// Licensed under the Apache License Version 2.0 that can be found in the
// LICENSE file in the root directory of this source tree.

import Foundation
import HealthKit
import SparklingMethod

private func healthAccessStatusString(_ status: HKAuthorizationStatus) -> String {
    switch status {
    case .sharingAuthorized:
        return "granted"
    case .sharingDenied:
        return "denied"
    case .notDetermined:
        return "notRequested"
    @unknown default:
        return "notRequested"
    }
}

@objc(HealthStatusResultModel)
final class HealthStatusResultModel: SPKMethodModel {
    var status: String = "notRequested"

    override func toDict() throws -> [String: Any]? {
        return ["status": status]
    }
}

@objc(HealthLastSevenDaysResultModel)
final class HealthLastSevenDaysResultModel: SPKMethodModel {
    var days: [[String: Any]] = []

    override func toDict() throws -> [String: Any]? {
        return ["days": days]
    }
}

private func dayDict(for total: HealthDayTotal, calendar: Calendar) -> [String: Any] {
    let comps = calendar.dateComponents([.year, .month, .day, .weekday], from: total.date)
    return [
        "year": comps.year ?? 0,
        "month": comps.month ?? 0,
        "day": comps.day ?? 0,
        "weekday": comps.weekday ?? 1,
        "steps": Int(total.steps.rounded()),
    ]
}

@objc(HealthStatusMethod)
public final class HealthStatusMethod: PipeMethod {
    public override var methodName: String { "health.getStatus" }
    public override class func methodName() -> String { "health.getStatus" }

    @objc public override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    @objc public override var resultModelClass: AnyClass { HealthStatusResultModel.self }

    @objc public override func call(withParamModel paramModel: Any, completionHandler: PipeMethod.CompletionHandlerProtocol) {
        let result = HealthStatusResultModel()
        result.status = healthAccessStatusString(HealthKitManager.shared.authorizationStatus())
        completionHandler.handleCompletion(status: .succeeded(), result: result)
    }
}

@objc(HealthRequestAccessMethod)
public final class HealthRequestAccessMethod: PipeMethod {
    public override var methodName: String { "health.requestAccess" }
    public override class func methodName() -> String { "health.requestAccess" }

    @objc public override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    @objc public override var resultModelClass: AnyClass { HealthStatusResultModel.self }

    @objc public override func call(withParamModel paramModel: Any, completionHandler: PipeMethod.CompletionHandlerProtocol) {
        HealthKitManager.shared.requestAuthorization { error in
            let result = HealthStatusResultModel()
            result.status = healthAccessStatusString(HealthKitManager.shared.authorizationStatus())
            if let error = error {
                completionHandler.handleCompletion(status: .failed(message: error.localizedDescription), result: result)
            } else {
                completionHandler.handleCompletion(status: .succeeded(), result: result)
            }
        }
    }
}

@objc(HealthLogStepsMethod)
public final class HealthLogStepsMethod: PipeMethod {
    public override var methodName: String { "health.logSteps" }
    public override class func methodName() -> String { "health.logSteps" }

    @objc public override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    @objc public override var resultModelClass: AnyClass { EmptyMethodModelClass.self }

    @objc public override func call(withParamModel paramModel: Any, completionHandler: PipeMethod.CompletionHandlerProtocol) {
        HealthKitManager.shared.logSteps(count: 500) { error in
            if let error = error {
                completionHandler.handleCompletion(status: .failed(message: error.localizedDescription), result: nil)
            } else {
                completionHandler.handleCompletion(status: .succeeded(), result: nil)
            }
        }
    }
}

@objc(HealthLastSevenDaysMethod)
public final class HealthLastSevenDaysMethod: PipeMethod {
    public override var methodName: String { "health.getLastSevenDays" }
    public override class func methodName() -> String { "health.getLastSevenDays" }

    @objc public override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    @objc public override var resultModelClass: AnyClass { HealthLastSevenDaysResultModel.self }

    @objc public override func call(withParamModel paramModel: Any, completionHandler: PipeMethod.CompletionHandlerProtocol) {
        let calendar = Calendar.current
        HealthKitManager.shared.lastSevenDaysStepTotals { result in
            switch result {
            case .success(let totals):
                let model = HealthLastSevenDaysResultModel()
                model.days = totals.map { dayDict(for: $0, calendar: calendar) }
                completionHandler.handleCompletion(status: .succeeded(), result: model)
            case .failure(let error):
                completionHandler.handleCompletion(status: .failed(message: error.localizedDescription), result: nil)
            }
        }
    }
}
