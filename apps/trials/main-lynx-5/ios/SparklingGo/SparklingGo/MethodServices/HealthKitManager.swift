import Foundation
import HealthKit

enum HealthKitError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Health data is not available on this device"
        }
    }
}

final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    static let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

    private init() {}

    // Reflects only sharing (write) authorization, per spec — HealthKit never exposes read authorization state.
    var currentStatus: String {
        guard HKHealthStore.isHealthDataAvailable() else { return "denied" }
        switch store.authorizationStatus(for: Self.stepType) {
        case .notDetermined:
            return "notRequested"
        case .sharingDenied:
            return "denied"
        case .sharingAuthorized:
            return "granted"
        @unknown default:
            return "notRequested"
        }
    }

    func requestAccess(completion: @escaping (Result<String, Error>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.failure(HealthKitError.unavailable))
            return
        }
        store.requestAuthorization(toShare: [Self.stepType], read: [Self.stepType]) { [weak self] _, error in
            guard let self else { return }
            if let error {
                completion(.failure(error))
                return
            }
            completion(.success(self.currentStatus))
        }
    }

    func logSteps(count: Double, completion: @escaping (Error?) -> Void) {
        let now = Date()
        let quantity = HKQuantity(unit: .count(), doubleValue: count)
        let sample = HKQuantitySample(type: Self.stepType, quantity: quantity, start: now, end: now)
        store.save(sample) { _, error in
            completion(error)
        }
    }

    func lastSevenDays(completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayStarts = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        let group = DispatchGroup()
        var resultsByIndex: [Int: [String: Any]] = [:]
        let lock = NSLock()
        var firstError: Error?

        for (index, dayStart) in dayStarts.enumerated() {
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            group.enter()
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: Self.stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                defer { group.leave() }
                lock.lock()
                defer { lock.unlock() }
                if let error {
                    if firstError == nil { firstError = error }
                    return
                }
                let sum = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                resultsByIndex[index] = [
                    "date": formatter.string(from: dayStart),
                    "steps": Int(sum.rounded()),
                    "isToday": calendar.isDateInToday(dayStart),
                ]
            }
            store.execute(query)
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            let ordered = (0..<dayStarts.count).compactMap { resultsByIndex[$0] }
            completion(.success(ordered))
        }
    }
}
