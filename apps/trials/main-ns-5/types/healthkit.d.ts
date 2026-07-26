// Minimal ambient declarations for the HealthKit symbols used from app/components/Health.vue.
// The iOS runtime exposes these as real globals at build time; full framework
// typings are only generated on demand via `ns typings ios`, so they are
// declared by hand here to keep the app's TypeScript checks clean.

interface HKObjectTypeRef {}
interface HKSampleTypeRef extends HKObjectTypeRef {}
interface HKQuantityTypeRef extends HKSampleTypeRef {}
interface HKUnitRef {}
interface HKQuantityRef {
  doubleValueForUnit(unit: HKUnitRef): number
}
interface HKQuantitySampleRef {
  startDate: Date
  quantity: HKQuantityRef
}
interface HKPredicateRef {}
interface HKSampleArrayRef {
  count: number
  objectAtIndex(index: number): HKQuantitySampleRef
}

declare const HKQuantityTypeIdentifierStepCount: string

declare const HKQuantityType: {
  quantityTypeForIdentifier(identifier: string): HKQuantityTypeRef
}

declare const HKUnit: {
  countUnit(): HKUnitRef
}

declare const HKQuantity: {
  quantityWithUnitDoubleValue(unit: HKUnitRef, value: number): HKQuantityRef
}

declare const HKQuantitySample: {
  quantitySampleWithTypeQuantityStartDateEndDate(
    type: HKQuantityTypeRef,
    quantity: HKQuantityRef,
    startDate: Date,
    endDate: Date,
  ): HKQuantitySampleRef
}

declare const HKQuery: {
  predicateForSamplesWithStartDateEndDateOptions(startDate: Date, endDate: Date, options: number): HKPredicateRef
}

declare const HKSampleQuery: {
  alloc(): {
    initWithSampleTypePredicateLimitSortDescriptorsResultsHandler(
      sampleType: HKSampleTypeRef,
      predicate: HKPredicateRef,
      limit: number,
      sortDescriptors: null,
      resultsHandler: (query: unknown, results: HKSampleArrayRef | null, error: NSErrorRef | null) => void,
    ): unknown
  }
}

interface NSErrorRef {
  localizedDescription: string
}

interface NSSetRef {}

declare const NSSet: {
  setWithObject(object: unknown): NSSetRef
}

interface HKHealthStoreRef {
  authorizationStatusForType(type: HKObjectTypeRef): number
  requestAuthorizationToShareTypesReadTypesCompletion(
    typesToShare: NSSetRef,
    typesToRead: NSSetRef,
    completion: (success: boolean, error: NSErrorRef | null) => void,
  ): void
  saveObjectWithCompletion(object: HKQuantitySampleRef, completion: (success: boolean, error: NSErrorRef | null) => void): void
  executeQuery(query: unknown): void
}

declare const HKHealthStore: {
  new (): HKHealthStoreRef
  isHealthDataAvailable(): boolean
}
