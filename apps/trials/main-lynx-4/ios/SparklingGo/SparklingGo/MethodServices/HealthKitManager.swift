// Copyright 2025 The Sparkling Authors. All rights reserved.
// Licensed under the Apache License Version 2.0 that can be found in the
// LICENSE file in the root directory of this source tree.

import Foundation
import HealthKit

struct HealthDayTotal {
    let date: Date
    let steps: Double
}

final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationStatus() -> HKAuthorizationStatus {
        store.authorizationStatus(for: stepType)
    }

    func requestAuthorization(completion: @escaping (Error?) -> Void) {
        guard isAvailable else {
            completion(NSError(domain: "HealthKitManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Health data is not available on this device"
            ]))
            return
        }
        store.requestAuthorization(toShare: [stepType], read: [stepType]) { _, error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }

    func logSteps(count: Double, completion: @escaping (Error?) -> Void) {
        let quantity = HKQuantity(unit: .count(), doubleValue: count)
        let now = Date()
        let sample = HKQuantitySample(type: stepType, quantity: quantity, start: now, end: now)
        store.save(sample) { _, error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }

    func lastSevenDaysStepTotals(completion: @escaping (Result<[HealthDayTotal], Error>) -> Void) {
        guard isAvailable else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Health data is not available on this device"
            ])))
            return
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let dayStarts = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: startOfToday) }

        let group = DispatchGroup()
        let lock = NSLock()
        var totals = [Date: Double](minimumCapacity: dayStarts.count)
        var firstError: Error?

        for dayStart in dayStarts {
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            group.enter()
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                lock.lock()
                let nsError = error as NSError?
                if let nsError = nsError, nsError.domain == HKError.errorDomain, nsError.code == HKError.Code.errorNoData.rawValue {
                    // No samples for this day is a normal outcome, not a failure.
                    totals[dayStart] = 0
                } else if let error = error {
                    if firstError == nil { firstError = error }
                } else {
                    totals[dayStart] = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                }
                lock.unlock()
                group.leave()
            }
            store.execute(query)
        }

        group.notify(queue: .main) {
            if let firstError = firstError {
                completion(.failure(firstError))
                return
            }
            completion(.success(dayStarts.map { HealthDayTotal(date: $0, steps: totals[$0] ?? 0) }))
        }
    }
}
