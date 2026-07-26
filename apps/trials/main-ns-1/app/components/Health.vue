<template>
    <Page @navigatedTo="onNavigatedTo">
        <ActionBar title="Health" />

        <StackLayout class="p-6">
            <Label :text="statusText" class="text-base" textWrap="true" />

            <Button text="Request Access" class="mt-4 p-3 bg-blue-500 text-white rounded" @tap="onRequestAccess" />
            <Button
                text="Log 500 Steps"
                :isEnabled="canLog"
                :class="canLog ? 'mt-2 p-3 bg-blue-500 text-white rounded' : 'mt-2 p-3 bg-gray-300 text-white rounded'"
                @tap="onLogSteps"
            />

            <Label text="Last 7 Days" class="text-lg font-bold mt-8" />

            <Label v-if="access !== 'granted'" text="Health access needed" class="text-gray-500 mt-2" />
            <StackLayout v-else>
                <Label
                    v-for="day in days"
                    :key="day.label"
                    :text="day.label"
                    :class="day.isToday ? 'font-bold mt-1' : 'mt-1'"
                    textWrap="true"
                />
            </StackLayout>
        </StackLayout>
    </Page>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import * as HealthKit from '../healthkit'
import type { AuthStatus, DayTotal } from '../healthkit'

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const statusText = ref('Health access: not requested')
const access = ref<AuthStatus>('not-requested')
const days = ref<{ label: string; isToday: boolean }[]>([])
const canLog = ref(false)

function statusLabel(state: AuthStatus): string {
    if (state === 'granted') return 'Health access: granted'
    if (state === 'denied') return 'Health access: denied'
    return 'Health access: not requested'
}

function withThousandsSeparators(n: number): string {
    return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function formatDay(day: DayTotal, isToday: boolean): string {
    const label = `${WEEKDAYS[day.date.getDay()]} ${MONTHS[day.date.getMonth()]} ${day.date.getDate()}`
    const stepsText = `${withThousandsSeparators(day.steps)} steps`
    return isToday ? `${label} — ${stepsText} (today)` : `${label} — ${stepsText}`
}

function refreshStatus() {
    access.value = HealthKit.getAuthStatus()
    statusText.value = statusLabel(access.value)
    canLog.value = access.value === 'granted'
}

async function refreshDays() {
    if (access.value !== 'granted') {
        days.value = []
        return
    }
    try {
        const totals = await HealthKit.loadLast7Days()
        days.value = totals.map((day, i) => ({
            label: formatDay(day, i === 0),
            isToday: i === 0
        }))
    } catch (error) {
        statusText.value = (error as Error).message
    }
}

function onNavigatedTo() {
    refreshStatus()
    refreshDays()
}

async function onRequestAccess() {
    if (!HealthKit.isAvailable()) {
        statusText.value = 'Health data is not available on this device'
        return
    }
    try {
        access.value = await HealthKit.requestAccess()
        statusText.value = statusLabel(access.value)
        canLog.value = access.value === 'granted'
        await refreshDays()
    } catch (error) {
        statusText.value = (error as Error).message
    }
}

async function onLogSteps() {
    try {
        await HealthKit.logSteps(500)
        await refreshDays()
    } catch (error) {
        statusText.value = (error as Error).message
    }
}
</script>
