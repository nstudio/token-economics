<template>
    <Page @navigatedTo="onShow">
        <ActionBar title="Health" />

        <StackLayout class="p-6">
            <Label :text="statusText" class="text-base mb-4" textWrap="true" />

            <Button text="Request Access" class="text-lg p-3 mb-3 bg-blue-500 text-white rounded-lg" @tap="onRequestAccess" />
            <Button
                text="Log 500 Steps"
                :isEnabled="canLogSteps"
                :class="canLogSteps ? 'text-lg p-3 mb-6 bg-blue-500 text-white rounded-lg' : 'text-lg p-3 mb-6 bg-gray-300 text-gray-500 rounded-lg'"
                @tap="onLogSteps"
            />

            <Label text="Last 7 Days" class="text-xl font-bold mb-2" textWrap="true" />

            <StackLayout v-if="authStatus === 'granted'">
                <Label
                    v-for="day in days"
                    :key="day.key"
                    :text="day.label"
                    :class="day.isToday ? 'text-base font-bold text-blue-600 mb-1' : 'text-base mb-1'"
                    textWrap="true"
                />
            </StackLayout>
            <Label v-else-if="authStatus === 'denied'" text="Health access needed" class="text-base text-gray-500" textWrap="true" />
            <Label v-else text="No data yet" class="text-base text-gray-500" textWrap="true" />
        </StackLayout>
    </Page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

type AuthStatus = 'not-determined' | 'granted' | 'denied'

interface DayRow {
    key: string
    label: string
    isToday: boolean
}

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const statusText = ref('Health access: not requested')
const authStatus = ref<AuthStatus>('not-determined')
const isSaving = ref(false)
const days = ref<DayRow[]>([])

const canLogSteps = computed(() => authStatus.value === 'granted' && !isSaving.value)

let store: HKHealthStore | null = null
function healthStore(): HKHealthStore {
    if (!store) store = HKHealthStore.new()
    return store
}

function stepType(): HKQuantityType {
    return HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)
}

function errorText(e: unknown): string {
    const err = e as { localizedDescription?: string; message?: string } | undefined
    if (err?.localizedDescription) return err.localizedDescription
    if (err?.message) return err.message
    return String(e)
}

function startOfDay(d: Date): Date {
    const r = new Date(d)
    r.setHours(0, 0, 0, 0)
    return r
}

function formatSteps(n: number): string {
    return Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function refreshAuthStatus() {
    const status = healthStore().authorizationStatusForType(stepType())
    if (status === HKAuthorizationStatus.SharingAuthorized) {
        authStatus.value = 'granted'
        statusText.value = 'Health access: granted'
    } else if (status === HKAuthorizationStatus.SharingDenied) {
        authStatus.value = 'denied'
        statusText.value = 'Health access: denied'
    } else {
        authStatus.value = 'not-determined'
        statusText.value = 'Health access: not requested'
    }
}

async function loadLast7Days() {
    const today = startOfDay(new Date())
    const start = new Date(today)
    start.setDate(start.getDate() - 6)
    const end = new Date(today)
    end.setDate(end.getDate() + 1)

    const predicate = HKQuery.predicateForSamplesWithStartDateEndDateOptions(start, end, HKQueryOptions.StrictStartDate)

    try {
        const results = await new Promise<NSArray<HKSample>>((resolve, reject) => {
            const query = new HKSampleQuery({
                sampleType: stepType(),
                predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [],
                resultsHandler: (_query, samples, error) => {
                    if (error) reject(error)
                    else resolve(samples)
                },
            })
            healthStore().executeQuery(query)
        })

        const totals = new Array(7).fill(0)
        const count = results.count
        for (let i = 0; i < count; i++) {
            const sample = results.objectAtIndex(i) as HKQuantitySample
            const steps = sample.quantity.doubleValueForUnit(HKUnit.countUnit())
            const dayIndex = Math.round((startOfDay(sample.startDate).getTime() - start.getTime()) / 86400000)
            if (dayIndex >= 0 && dayIndex < 7) totals[dayIndex] += steps
        }

        const rows: DayRow[] = []
        for (let i = 6; i >= 0; i--) {
            const d = new Date(start)
            d.setDate(d.getDate() + i)
            const isToday = i === 6
            const dayLabel = `${WEEKDAYS[d.getDay()]} ${MONTHS[d.getMonth()]} ${d.getDate()}`
            const suffix = isToday ? ' (today)' : ''
            rows.push({ key: String(i), label: `${dayLabel} — ${formatSteps(totals[i])} steps${suffix}`, isToday })
        }
        days.value = rows
    } catch (e) {
        statusText.value = errorText(e)
    }
}

async function onRequestAccess() {
    if (!HKHealthStore.isHealthDataAvailable()) {
        statusText.value = 'Health data is not available on this device.'
        return
    }
    try {
        await new Promise<void>((resolve, reject) => {
            healthStore().requestAuthorizationToShareTypesReadTypesCompletion(NSSet.setWithObject(stepType()), NSSet.setWithObject(stepType()), (success, error) => {
                if (error) reject(error)
                else resolve()
            })
        })
    } catch (e) {
        statusText.value = errorText(e)
        return
    }
    refreshAuthStatus()
    if (authStatus.value === 'granted') {
        await loadLast7Days()
    }
}

async function onLogSteps() {
    if (!canLogSteps.value) return
    isSaving.value = true
    try {
        const now = new Date()
        const quantity = HKQuantity.quantityWithUnitDoubleValue(HKUnit.countUnit(), 500)
        const sample = HKQuantitySample.quantitySampleWithTypeQuantityStartDateEndDate(stepType(), quantity, now, now)
        await new Promise<void>((resolve, reject) => {
            healthStore().saveObjectWithCompletion(sample, (success, error) => {
                if (error) reject(error)
                else resolve()
            })
        })
        await loadLast7Days()
    } catch (e) {
        statusText.value = errorText(e)
    } finally {
        isSaving.value = false
    }
}

function onShow() {
    if (!HKHealthStore.isHealthDataAvailable()) {
        statusText.value = 'Health data is not available on this device.'
        return
    }
    refreshAuthStatus()
    if (authStatus.value === 'granted') {
        loadLast7Days()
    }
}
</script>
