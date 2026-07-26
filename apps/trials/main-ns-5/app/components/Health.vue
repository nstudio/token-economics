<template>
    <Page @navigatedTo="refreshStatus">
        <ActionBar title="Health" />
        <ScrollView>
            <StackLayout class="p-6">
                <Label :text="statusText" class="text-base text-gray-600 mb-4" textWrap="true" />
                <Button text="Request Access" class="mb-3 bg-blue-500 text-white rounded-lg p-4" @tap="requestAccess" />
                <Button
                    text="Log 500 Steps"
                    :isEnabled="accessGranted"
                    :class="accessGranted ? 'bg-blue-500 text-white' : 'bg-gray-300 text-gray-500'"
                    class="mb-8 rounded-lg p-4"
                    @tap="logSteps"
                />
                <Label text="Last 7 Days" class="text-lg font-bold mb-2" />
                <StackLayout v-if="accessGranted">
                    <Label
                        v-for="row in days"
                        :key="row.text"
                        :text="row.text"
                        :class="row.isToday ? 'font-bold text-blue-600' : 'text-gray-700'"
                        class="mb-1"
                        textWrap="true"
                    />
                </StackLayout>
                <Label v-else text="Health access needed" class="text-gray-400 text-center" textWrap="true" />
            </StackLayout>
        </ScrollView>
    </Page>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { Utils } from '@nativescript/core'

// Apple's HKAuthorizationStatus/HKQueryOptions/HKObjectQueryNoLimit are fixed
// integer constants; using them directly avoids depending on the exact shape
// the metadata generator produces for nested enum namespaces.
const HK_AUTH_DENIED = 1
const HK_AUTH_AUTHORIZED = 2
const HK_QUERY_NO_OPTIONS = 0
const HK_QUERY_NO_LIMIT = 0

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

interface DayRow {
    text: string
    isToday: boolean
}

const statusText = ref('Health access: not requested')
const accessGranted = ref(false)
const days = ref<DayRow[]>([])

function stepType() {
    return HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)
}

function dayKey(date: Date): string {
    return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`
}

function formatRow(date: Date, steps: number, isToday: boolean): string {
    const label = `${WEEKDAYS[date.getDay()]} ${MONTHS[date.getMonth()]} ${date.getDate()} — ${steps.toLocaleString('en-US')} steps`
    return isToday ? `${label} (today)` : label
}

function refreshStatus() {
    if (!HKHealthStore.isHealthDataAvailable()) {
        statusText.value = 'Health error: HealthKit is not available on this device'
        accessGranted.value = false
        days.value = []
        return
    }

    const store = new HKHealthStore()
    const status = store.authorizationStatusForType(stepType())

    if (status === HK_AUTH_AUTHORIZED) {
        statusText.value = 'Health access: granted'
        accessGranted.value = true
        loadLastSevenDays()
    } else if (status === HK_AUTH_DENIED) {
        statusText.value = 'Health access: denied'
        accessGranted.value = false
        days.value = []
    } else {
        statusText.value = 'Health access: not requested'
        accessGranted.value = false
        days.value = []
    }
}

function requestAccess() {
    if (!HKHealthStore.isHealthDataAvailable()) {
        statusText.value = 'Health error: HealthKit is not available on this device'
        return
    }

    const store = new HKHealthStore()
    const types = NSSet.setWithObject(stepType())

    store.requestAuthorizationToShareTypesReadTypesCompletion(types, types, (success, error) => {
        Utils.dispatchToMainThread(() => {
            if (!success && error) {
                statusText.value = `Health error: ${error.localizedDescription}`
            }
            refreshStatus()
        })
    })
}

function logSteps() {
    const quantity = HKQuantity.quantityWithUnitDoubleValue(HKUnit.countUnit(), 500)
    const now = new Date()
    const sample = HKQuantitySample.quantitySampleWithTypeQuantityStartDateEndDate(stepType(), quantity, now, now)
    const store = new HKHealthStore()

    store.saveObjectWithCompletion(sample, (success, error) => {
        Utils.dispatchToMainThread(() => {
            if (success) {
                loadLastSevenDays()
            } else {
                statusText.value = `Health error: ${error ? error.localizedDescription : 'failed to save steps'}`
            }
        })
    })
}

function loadLastSevenDays() {
    const store = new HKHealthStore()
    const now = new Date()
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    const startOfWindow = new Date(startOfToday)
    startOfWindow.setDate(startOfWindow.getDate() - 6)

    const predicate = HKQuery.predicateForSamplesWithStartDateEndDateOptions(startOfWindow, now, HK_QUERY_NO_OPTIONS)
    const query = HKSampleQuery.alloc().initWithSampleTypePredicateLimitSortDescriptorsResultsHandler(
        stepType(),
        predicate,
        HK_QUERY_NO_LIMIT,
        null,
        (_query, results, error) => {
            Utils.dispatchToMainThread(() => {
                if (error) {
                    statusText.value = `Health error: ${error.localizedDescription}`
                    return
                }

                const totals = new Map<string, number>()
                const count = results ? results.count : 0
                for (let i = 0; i < count; i++) {
                    const sample = results!.objectAtIndex(i)
                    const key = dayKey(sample.startDate)
                    const steps = sample.quantity.doubleValueForUnit(HKUnit.countUnit())
                    totals.set(key, (totals.get(key) ?? 0) + steps)
                }

                const rows: DayRow[] = []
                for (let offset = 0; offset < 7; offset++) {
                    const d = new Date(startOfToday)
                    d.setDate(d.getDate() - offset)
                    const isToday = offset === 0
                    const steps = Math.round(totals.get(dayKey(d)) ?? 0)
                    rows.push({ text: formatRow(d, steps, isToday), isToday })
                }
                days.value = rows
            })
        },
    )
    store.executeQuery(query)
}
</script>
