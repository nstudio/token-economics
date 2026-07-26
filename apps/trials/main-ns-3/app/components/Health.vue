<template>
    <Page @navigatedTo="onNavigatedTo">
        <ActionBar title="Health" />

        <StackLayout class="p-6">
            <Label :text="statusText" class="text-base text-gray-600 mb-4" textWrap="true" />

            <Button text="Request Access" class="text-base bg-blue-500 text-white p-3 rounded-lg mb-2" @tap="requestAccess" />
            <Button text="Log 500 Steps" :isEnabled="canLog" :class="logButtonClass" @tap="logSteps" />

            <Label text="Last 7 Days" class="text-lg font-semibold text-gray-800 mb-2 mt-4" />

            <Label v-if="!granted" text="Health access needed" class="text-base text-gray-400" textWrap="true" />
            <StackLayout v-else>
                <Label
                    v-for="day in days"
                    :key="day.key"
                    :text="day.label"
                    :class="day.isToday ? 'text-base font-bold text-blue-600 mb-1' : 'text-base text-gray-700 mb-1'"
                    textWrap="true"
                />
            </StackLayout>
        </StackLayout>
    </Page>
</template>

<script setup lang="ts">
import { Utils } from '@nativescript/core'
import { computed, ref } from 'vue'

interface DayRow {
  key: string
  label: string
  isToday: boolean
}

// Ambient `const enum`s from the iOS type defs aren't inlined by esbuild across files,
// so reference HealthKit's underlying integer values directly instead of the enum names.
const HK_AUTH_SHARING_DENIED = 1
const HK_AUTH_SHARING_AUTHORIZED = 2
const HK_QUERY_OPTIONS_NONE = 0
const HK_STATISTICS_CUMULATIVE_SUM = 16
const NS_CALENDAR_UNIT_DAY = 16
const NS_CALENDAR_OPTIONS_NONE = 0 as NSCalendarOptions

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const stepType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)
const healthStore = HKHealthStore.new()

const statusText = ref('Health access: not requested')
const granted = ref(false)
const canLog = ref(false)
const days = ref<DayRow[]>([])

const logButtonClass = computed(() =>
  canLog.value ? 'text-base bg-blue-500 text-white p-3 rounded-lg mb-6' : 'text-base bg-gray-300 text-gray-500 p-3 rounded-lg mb-6'
)

function withThousandsSeparators(value: number): string {
  return value.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function formatDayLabel(date: Date, steps: number, isToday: boolean): string {
  const weekday = WEEKDAYS[date.getDay()]
  const month = MONTHS[date.getMonth()]
  const stepsText = withThousandsSeparators(steps)
  const suffix = isToday ? ' (today)' : ''
  return `${weekday} ${month} ${date.getDate()} — ${stepsText} steps${suffix}`
}

function loadLast7Days() {
  const calendar = NSCalendar.currentCalendar
  const startOfToday = calendar.startOfDayForDate(new Date())
  const startOfRange = calendar.dateByAddingUnitValueToDateOptions(NS_CALENDAR_UNIT_DAY, -6, startOfToday, NS_CALENDAR_OPTIONS_NONE)
  const endOfRange = calendar.dateByAddingUnitValueToDateOptions(NS_CALENDAR_UNIT_DAY, 1, startOfToday, NS_CALENDAR_OPTIONS_NONE)
  const predicate = HKQuery.predicateForSamplesWithStartDateEndDateOptions(startOfRange, endOfRange, HK_QUERY_OPTIONS_NONE)

  const intervalComponents = NSDateComponents.new()
  intervalComponents.day = 1

  const query = HKStatisticsCollectionQuery.alloc().initWithQuantityTypeQuantitySamplePredicateOptionsAnchorDateIntervalComponents(
    stepType,
    predicate,
    HK_STATISTICS_CUMULATIVE_SUM,
    startOfRange,
    intervalComponents
  )

  query.initialResultsHandler = (_query, collection, error) => {
    Utils.dispatchToMainThread(() => {
      if (error) {
        statusText.value = error.localizedDescription
        return
      }
      const rows: DayRow[] = []
      for (let i = 0; i < 7; i++) {
        const dayStart = calendar.dateByAddingUnitValueToDateOptions(NS_CALENDAR_UNIT_DAY, -i, startOfToday, NS_CALENDAR_OPTIONS_NONE)
        const stats = collection?.statisticsForDate(dayStart)
        const sum = stats?.sumQuantity()
        const steps = sum ? Math.round(sum.doubleValueForUnit(HKUnit.countUnit())) : 0
        rows.push({
          key: dayStart.toISOString(),
          label: formatDayLabel(dayStart, steps, i === 0),
          isToday: i === 0
        })
      }
      days.value = rows
    })
  }

  healthStore.executeQuery(query)
}

function refreshStatus() {
  const status = healthStore.authorizationStatusForType(stepType)

  if (status === HK_AUTH_SHARING_AUTHORIZED) {
    statusText.value = 'Health access: granted'
    granted.value = true
    canLog.value = true
  } else if (status === HK_AUTH_SHARING_DENIED) {
    statusText.value = 'Health access: denied'
    granted.value = false
    canLog.value = false
  } else {
    statusText.value = 'Health access: not requested'
    granted.value = false
    canLog.value = false
  }

  if (granted.value) {
    loadLast7Days()
  } else {
    days.value = []
  }
}

function requestAccess() {
  if (!HKHealthStore.isHealthDataAvailable()) {
    statusText.value = 'Health data is not available on this device'
    return
  }

  const types = NSSet.setWithArray([stepType])

  healthStore.requestAuthorizationToShareTypesReadTypesCompletion(types, types, (_success, error) => {
    Utils.dispatchToMainThread(() => {
      if (error) {
        statusText.value = error.localizedDescription
        return
      }
      refreshStatus()
    })
  })
}

function logSteps() {
  if (!canLog.value) return

  const quantity = HKQuantity.quantityWithUnitDoubleValue(HKUnit.countUnit(), 500)
  const now = new Date()
  const sample = HKQuantitySample.quantitySampleWithTypeQuantityStartDateEndDate(stepType, quantity, now, now)

  healthStore.saveObjectWithCompletion(sample, (success, error) => {
    Utils.dispatchToMainThread(() => {
      if (!success) {
        statusText.value = error?.localizedDescription ?? 'Failed to log steps'
        return
      }
      loadLast7Days()
    })
  })
}

function onNavigatedTo() {
  refreshStatus()
}
</script>
