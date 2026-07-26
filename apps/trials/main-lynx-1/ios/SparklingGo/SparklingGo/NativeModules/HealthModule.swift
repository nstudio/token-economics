// Copyright 2025 The Sparkling Authors. All rights reserved.
// Licensed under the Apache License Version 2.0 that can be found in the
// LICENSE file in the root directory of this source tree.

import Foundation
import HealthKit
import Lynx

@objc(HealthModule)
@objcMembers
public class HealthModule: NSObject, LynxModule {
    public static var name: String { "HealthModule" }

    public static var methodLookup: [String: String] {
        return [
            "getAuthorizationStatus": NSStringFromSelector(#selector(getAuthorizationStatus(_:))),
            "requestAuthorization": NSStringFromSelector(#selector(requestAuthorization(_:))),
            "logSteps": NSStringFromSelector(#selector(logSteps(_:callback:))),
            "getLast7Days": NSStringFromSelector(#selector(getLast7Days(_:))),
        ]
    }

    private let healthStore = HKHealthStore()
    private static let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

    public required init(param: Any) {
        super.init()
    }

    public override required init() {
        super.init()
    }

    private func currentStatus() -> String {
        guard HKHealthStore.isHealthDataAvailable() else { return "denied" }
        switch healthStore.authorizationStatus(for: Self.stepType) {
        case .notDetermined: return "not_requested"
        case .sharingAuthorized: return "granted"
        case .sharingDenied: return "denied"
        @unknown default: return "denied"
        }
    }

    func getAuthorizationStatus(_ callback: @escaping (NSDictionary) -> Void) {
        callback(["status": currentStatus()])
    }

    func requestAuthorization(_ callback: @escaping (NSDictionary) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            callback(["status": "denied"])
            return
        }
        healthStore.requestAuthorization(toShare: [Self.stepType], read: [Self.stepType]) { [weak self] _, _ in
            let status = self?.currentStatus() ?? "denied"
            DispatchQueue.main.async {
                callback(["status": status])
            }
        }
    }

    func logSteps(_ steps: Double, callback: @escaping (NSDictionary) -> Void) {
        let now = Date()
        let quantity = HKQuantity(unit: .count(), doubleValue: steps)
        let sample = HKQuantitySample(type: Self.stepType, quantity: quantity, start: now, end: now)
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                if success {
                    callback(["success": true])
                } else {
                    callback(["success": false, "error": error?.localizedDescription ?? "Failed to save steps"])
                }
            }
        }
    }

    func getLast7Days(_ callback: @escaping (NSArray) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayStarts = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = calendar.timeZone

        var totals = [String: Double](minimumCapacity: dayStarts.count)
        let group = DispatchGroup()

        for dayStart in dayStarts {
            let key = dateFormatter.string(from: dayStart)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            group.enter()
            let query = HKStatisticsQuery(quantityType: Self.stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                totals[key] = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                group.leave()
            }
            healthStore.execute(query)
        }

        group.notify(queue: .main) {
            let days = dayStarts.map { dayStart -> [String: Any] in
                let key = dateFormatter.string(from: dayStart)
                return ["date": key, "steps": Int(totals[key] ?? 0)]
            }
            callback(days as NSArray)
        }
    }
}
