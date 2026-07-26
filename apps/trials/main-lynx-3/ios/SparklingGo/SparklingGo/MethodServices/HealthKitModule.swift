// Copyright 2025 The Sparkling Authors. All rights reserved.
// Licensed under the Apache License Version 2.0 that can be found in the
// LICENSE file in the root directory of this source tree.

import Foundation
import HealthKit
import Lynx

@objc(HealthKitModule)
final class HealthKitModule: NSObject, LynxModule {
    static var name: String { "HealthKitModule" }

    static var methodLookup: [String: String] {
        return [
            "getAuthorizationStatus": NSStringFromSelector(#selector(getAuthorizationStatus(_:))),
            "requestAuthorization": NSStringFromSelector(#selector(requestAuthorization(_:))),
            "logSteps": NSStringFromSelector(#selector(logSteps(_:callback:))),
            "getLast7Days": NSStringFromSelector(#selector(getLast7Days(_:))),
        ]
    }

    private static let healthStore = HKHealthStore()
    private static let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

    override init() {
        super.init()
    }

    init(param: Any) {
        super.init()
    }

    @objc func getAuthorizationStatus(_ callback: @escaping LynxCallbackBlock) {
        callback(Self.statusString(for: Self.healthStore.authorizationStatus(for: Self.stepType)))
    }

    @objc func requestAuthorization(_ callback: @escaping LynxCallbackBlock) {
        guard HKHealthStore.isHealthDataAvailable() else {
            callback(["status": "denied", "error": "Health data is not available on this device"])
            return
        }
        Self.healthStore.requestAuthorization(toShare: [Self.stepType], read: [Self.stepType]) { _, error in
            let status = Self.statusString(for: Self.healthStore.authorizationStatus(for: Self.stepType))
            if let error = error {
                callback(["status": status, "error": error.localizedDescription])
            } else {
                callback(["status": status])
            }
        }
    }

    @objc func logSteps(_ steps: NSNumber, callback: @escaping LynxCallbackBlock) {
        let now = Date()
        let quantity = HKQuantity(unit: .count(), doubleValue: steps.doubleValue)
        let sample = HKQuantitySample(type: Self.stepType, quantity: quantity, start: now, end: now)
        Self.healthStore.save(sample) { success, error in
            if success {
                callback(["success": true])
            } else {
                callback(["success": false, "error": error?.localizedDescription ?? "Unknown error saving steps"])
            }
        }
    }

    @objc func getLast7Days(_ callback: @escaping LynxCallbackBlock) {
        let calendar = Calendar.current
        guard let startOfToday = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: Date())),
              let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday),
              let endDate = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            callback(["success": false, "error": "Failed to compute date range"])
            return
        }

        var interval = DateComponents()
        interval.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: Self.stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startOfToday,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
                callback(["success": false, "error": error?.localizedDescription ?? "Unknown error reading steps"])
                return
            }
            var days: [[String: Any]] = []
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                days.append([
                    "dateMs": statistics.startDate.timeIntervalSince1970 * 1000,
                    "steps": steps,
                    "isToday": calendar.isDateInToday(statistics.startDate),
                ])
            }
            callback(["success": true, "days": days.reversed()])
        }

        Self.healthStore.execute(query)
    }

    private static func statusString(for status: HKAuthorizationStatus) -> String {
        switch status {
        case .sharingAuthorized: return "authorized"
        case .sharingDenied: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }
}
