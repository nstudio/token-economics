export type HealthAuthStatus = 'not-requested' | 'granted' | 'denied'

export interface DayTotal {
    date: Date
    steps: number
}

const stepType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)

let healthStore: HKHealthStore | null = null

function getStore(): HKHealthStore {
    if (!healthStore) {
        healthStore = HKHealthStore.new()
    }
    return healthStore
}

function toError(error: NSError): Error {
    return new Error(error.localizedDescription)
}

export function getAuthStatus(): HealthAuthStatus {
    if (!HKHealthStore.isHealthDataAvailable()) {
        return 'denied'
    }
    switch (getStore().authorizationStatusForType(stepType)) {
        case HKAuthorizationStatus.SharingAuthorized:
            return 'granted'
        case HKAuthorizationStatus.SharingDenied:
            return 'denied'
        default:
            return 'not-requested'
    }
}

export function requestAuthorization(): Promise<HealthAuthStatus> {
    return new Promise((resolve, reject) => {
        if (!HKHealthStore.isHealthDataAvailable()) {
            resolve('denied')
            return
        }
        const typesToShare = NSSet.setWithObject<HKSampleType>(stepType)
        const typesToRead = NSSet.setWithObject<HKObjectType>(stepType)
        getStore().requestAuthorizationToShareTypesReadTypesCompletion(typesToShare, typesToRead, (_success, error) => {
            if (error) {
                reject(toError(error))
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
        const sample = HKQuantitySample.quantitySampleWithTypeQuantityStartDateEndDate(stepType, quantity, now, now)
        getStore().saveObjectWithCompletion(sample, (_success, error) => {
            if (error) {
                reject(toError(error))
                return
            }
            resolve()
        })
    })
}

export function loadLast7Days(): Promise<DayTotal[]> {
    return new Promise((resolve, reject) => {
        const calendar = NSCalendar.currentCalendar
        const startOfToday = calendar.startOfDayForDate(new Date())
        const startDate = calendar.dateByAddingUnitValueToDateOptions(NSCalendarUnit.CalendarUnitDay, -6, startOfToday, 0 as NSCalendarOptions)
        const predicate = HKQuery.predicateForSamplesWithStartDateEndDateOptions(startDate, new Date(), HKQueryOptions.None)

        const query = new HKSampleQuery({
            sampleType: stepType,
            predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [],
            resultsHandler: (_query, results, error) => {
                if (error) {
                    reject(toError(error))
                    return
                }

                const totals = new Map<number, number>()
                const count = results ? results.count : 0
                for (let i = 0; i < count; i++) {
                    const sample = results.objectAtIndex(i) as HKQuantitySample
                    const dayStart = calendar.startOfDayForDate(sample.startDate)
                    const key = dayStart.getTime()
                    const steps = sample.quantity.doubleValueForUnit(HKUnit.countUnit())
                    totals.set(key, (totals.get(key) ?? 0) + steps)
                }

                const days: DayTotal[] = []
                for (let i = 0; i < 7; i++) {
                    const date = calendar.dateByAddingUnitValueToDateOptions(NSCalendarUnit.CalendarUnitDay, -i, startOfToday, 0 as NSCalendarOptions)
                    days.push({ date, steps: totals.get(date.getTime()) ?? 0 })
                }
                resolve(days)
            },
        })
        getStore().executeQuery(query)
    })
}
