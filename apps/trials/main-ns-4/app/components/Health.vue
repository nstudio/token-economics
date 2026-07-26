<template>
    <Page @navigatedTo="onNavigatedTo">
        <ActionBar title="Health">
            <NavigationButton text="Back" @tap="$navigateBack" />
        </ActionBar>

        <StackLayout class="p-4">
            <Label :text="statusText" class="text-base text-gray-700" textWrap="true" />

            <Button text="Request Access" class="bg-blue-500 text-white rounded-lg py-3 mt-4" @tap="onRequestAccess" />

            <Button text="Log 500 Steps" :isEnabled="accessGranted"
                :class="accessGranted ? 'bg-blue-500 text-white rounded-lg py-3 mt-3' : 'bg-gray-300 text-gray-500 rounded-lg py-3 mt-3'"
                @tap="onLogSteps" />

            <Label text="Last 7 Days" class="text-lg font-bold mt-8" textWrap="true" />

            <Label v-if="!accessGranted" text="Health access needed" class="text-base text-gray-500 mt-2" textWrap="true" />

            <StackLayout v-else class="mt-2">
                <Label v-for="day in days" :key="day.key" :text="day.text"
                    :class="day.isToday ? 'text-base font-bold text-blue-600 mt-1' : 'text-base text-gray-700 mt-1'"
                    textWrap="true" />
            </StackLayout>
        </StackLayout>
    </Page>
</template>

<script setup lang="ts">
import { $navigateBack } from 'nativescript-vue'
import { computed, ref } from 'vue'
import { getAuthStatus, loadLast7Days, logSteps, requestAuthorization, type HealthAuthStatus } from '~/native/healthkit'

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function statusLabel(status: HealthAuthStatus): string {
    switch (status) {
        case 'granted':
            return 'Health access: granted'
        case 'denied':
            return 'Health access: denied'
        default:
            return 'Health access: not requested'
    }
}

function dayLabel(date: Date): string {
    return `${WEEKDAYS[date.getDay()]} ${MONTHS[date.getMonth()]} ${date.getDate()}`
}

function formatSteps(steps: number): string {
    return Math.round(steps).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function errorMessage(e: unknown): string {
    return e instanceof Error ? e.message : String(e)
}

const authStatus = ref<HealthAuthStatus>('not-requested')
const statusText = ref(statusLabel('not-requested'))
const days = ref<{ key: number; text: string; isToday: boolean }[]>([])

const accessGranted = computed(() => authStatus.value === 'granted')

async function refreshDays() {
    try {
        const totals = await loadLast7Days()
        const todayKey = totals[0]?.date.getTime()
        days.value = totals.map(({ date, steps }) => {
            const isToday = date.getTime() === todayKey
            const text = `${dayLabel(date)} — ${formatSteps(steps)} steps${isToday ? ' (today)' : ''}`
            return { key: date.getTime(), text, isToday }
        })
    } catch (e) {
        statusText.value = errorMessage(e)
    }
}

async function refreshStatus() {
    authStatus.value = getAuthStatus()
    statusText.value = statusLabel(authStatus.value)
    if (accessGranted.value) {
        await refreshDays()
    }
}

async function onRequestAccess() {
    try {
        authStatus.value = await requestAuthorization()
        statusText.value = statusLabel(authStatus.value)
        if (accessGranted.value) {
            await refreshDays()
        }
    } catch (e) {
        statusText.value = errorMessage(e)
    }
}

async function onLogSteps() {
    try {
        await logSteps(500)
        await refreshDays()
    } catch (e) {
        statusText.value = errorMessage(e)
    }
}

function onNavigatedTo() {
    refreshStatus()
}
</script>
