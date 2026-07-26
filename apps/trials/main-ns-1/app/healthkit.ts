export type AuthStatus = 'not-requested' | 'granted' | 'denied'

export interface DayTotal {
    date: Date
    steps: number
}

const stepsType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)
const healthStore = HKHealthStore.new()

const NoCalendarOptions = 0 as NSCalendarOptions

function toAuthStatus(status: HKAuthorizationStatus): AuthStatus {
    switch (status) {
        case HKAuthorizationStatus.SharingAuthorized:
            return 'granted'
        case HKAuthorizationStatus.SharingDenied:
            return 'denied'
        default:
            return 'not-requested'
    }
}

export function isAvailable(): boolean {
    return HKHealthStore.isHealthDataAvailable()
}

export function getAuthStatus(): AuthStatus {
    return toAuthStatus(healthStore.authorizationStatusForType(stepsType))
}

export function requestAccess(): Promise<AuthStatus> {
    return new Promise((resolve, reject) => {
        const typesToShare = NSSet.setWithObject<HKSampleType>(stepsType)
        const typesToRead = NSSet.setWithObject<HKObjectType>(stepsType)
        healthStore.requestAuthorizationToShareTypesReadTypesCompletion(typesToShare, typesToRead, (success, error) => {
            if (error) {
                reject(new Error(error.localizedDescription))
                return
            }
            resolve(getAuthStatus())
        })
    })
}

export function logSteps(count: number): Promise<void> {
    return new Promise((resolve, reject) => {
        const now = new Date()
        const quantity = HKQuantity.quantityWithUnitDoubleValue(HKUnit.countUnit(), count)
        const sample = HKQuantitySample.quantitySampleWithTypeQuantityStartDateEndDate(stepsType, quantity, now, now)
        healthStore.saveObjectWithCompletion(sample, (success, error) => {
            if (error) {
                reject(new Error(error.localizedDescription))
                return
            }
            resolve()
        })
    })
}

export function loadLast7Days(): Promise<DayTotal[]> {
    return new Promise((resolve, reject) => {
        const calendar = NSCalendar.currentCalendar
        const todayStart = calendar.startOfDayForDate(new Date())
        const rangeStart = calendar.dateByAddingUnitValueToDateOptions(NSCalendarUnit.CalendarUnitDay, -6, todayStart, NoCalendarOptions)
        const rangeEnd = calendar.dateByAddingUnitValueToDateOptions(NSCalendarUnit.CalendarUnitDay, 1, todayStart, NoCalendarOptions)
        const predicate = HKQuery.predicateForSamplesWithStartDateEndDateOptions(rangeStart, rangeEnd, HKQueryOptions.None)

        const intervalComponents = NSDateComponents.new()
        intervalComponents.day = 1

        const query = new HKStatisticsCollectionQuery({
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: HKStatisticsOptions.CumulativeSum,
            anchorDate: todayStart,
            intervalComponents
        })

        query.initialResultsHandler = (q, collection, error) => {
            if (error || !collection) {
                reject(new Error(error ? error.localizedDescription : 'Failed to load step data'))
                return
            }

            const days: DayTotal[] = []
            for (let i = 0; i <= 6; i++) {
                const dayDate = calendar.dateByAddingUnitValueToDateOptions(NSCalendarUnit.CalendarUnitDay, -i, todayStart, NoCalendarOptions)
                const stats = collection.statisticsForDate(dayDate)
                const sum = stats ? stats.sumQuantity() : null
                const steps = sum ? sum.doubleValueForUnit(HKUnit.countUnit()) : 0
                days.push({ date: dayDate, steps: Math.round(steps) })
            }
            resolve(days)
        }

        healthStore.executeQuery(query)
    })
}
