import Foundation
import HealthKit
import Lynx

@objc(HealthKitModule)
@objcMembers
public final class HealthKitModule: NSObject, LynxModule {

    public static var name: String { "HealthKitModule" }

    public static var methodLookup: [String: String] {
        [
            "getAuthorizationStatus": NSStringFromSelector(#selector(getAuthorizationStatus(_:))),
            "requestAuthorization": NSStringFromSelector(#selector(requestAuthorization(_:))),
            "logSteps": NSStringFromSelector(#selector(logSteps(_:callback:))),
            "getLast7Days": NSStringFromSelector(#selector(getLast7Days(_:))),
        ]
    }

    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

    public override init() {
        super.init()
    }

    public init(param: Any) {
        super.init()
    }

    private func statusString(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .sharingAuthorized: return "authorized"
        case .sharingDenied: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    @objc func getAuthorizationStatus(_ callback: @escaping (NSDictionary) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            callback(["status": "denied"])
            return
        }
        callback(["status": statusString(healthStore.authorizationStatus(for: stepType))])
    }

    @objc func requestAuthorization(_ callback: @escaping (NSDictionary) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            callback(["status": "denied", "error": "Health data is not available on this device"])
            return
        }
        healthStore.requestAuthorization(toShare: [stepType], read: [stepType]) { [weak self] _, error in
            guard let self = self else { return }
            let status = self.statusString(self.healthStore.authorizationStatus(for: self.stepType))
            callback(["status": status, "error": error?.localizedDescription ?? NSNull()])
        }
    }

    @objc func logSteps(_ steps: Double, callback: @escaping (NSDictionary) -> Void) {
        let quantity = HKQuantity(unit: .count(), doubleValue: steps)
        let now = Date()
        let sample = HKQuantitySample(type: stepType, quantity: quantity, start: now, end: now)
        healthStore.save(sample) { success, error in
            callback(["success": success, "error": error?.localizedDescription ?? NSNull()])
        }
    }

    @objc func getLast7Days(_ callback: @escaping (NSArray) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            callback([])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday),
              let endDate = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            callback([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        var intervalComponents = DateComponents()
        intervalComponents.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startOfToday,
            intervalComponents: intervalComponents
        )

        query.initialResultsHandler = { _, results, error in
            guard error == nil, let results = results else {
                callback([])
                return
            }

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "EEE MMM d"

            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            numberFormatter.locale = Locale(identifier: "en_US")

            var entries: [[String: Any]] = []
            for offset in stride(from: 6, through: 0, by: -1) {
                guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { continue }
                let sum = results.statistics()
                    .first(where: { calendar.isDate($0.startDate, inSameDayAs: dayStart) })?
                    .sumQuantity()?.doubleValue(for: .count()) ?? 0
                let steps = Int(sum.rounded())
                let isToday = calendar.isDate(dayStart, inSameDayAs: now)
                let stepsText = numberFormatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
                var text = "\(dateFormatter.string(from: dayStart)) — \(stepsText) steps"
                if isToday {
                    text += " (today)"
                }
                entries.append(["text": text, "isToday": isToday])
            }
            entries.reverse()

            callback(entries as NSArray)
        }

        healthStore.execute(query)
    }
}
