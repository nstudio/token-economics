<script setup lang="ts">
import { close } from 'sparkling-navigation'
import { computed, onMounted, ref } from 'vue-lynx'

import './App.css'

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

type AuthStatus = 'not_requested' | 'granted' | 'denied'

const authStatus = ref<AuthStatus>('not_requested')
const errorText = ref<string | null>(null)
const days = ref<{ date: string; steps: number }[]>([])

const statusText = computed(() => {
  if (errorText.value) return errorText.value
  if (authStatus.value === 'granted') return 'Health access: granted'
  if (authStatus.value === 'denied') return 'Health access: denied'
  return 'Health access: not requested'
})

const logDisabled = computed(() => authStatus.value !== 'granted')

function formatThousands(n: number): string {
  return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function formatDayLabel(dateStr: string): string {
  const [year, month, day] = dateStr.split('-').map(Number)
  const d = new Date(year, month - 1, day)
  return `${WEEKDAYS[d.getDay()]} ${MONTHS[d.getMonth()]} ${d.getDate()}`
}

function dayText(day: { date: string; steps: number }, index: number): string {
  const label = `${formatDayLabel(day.date)} — ${formatThousands(day.steps)} steps`
  return index === 0 ? `${label} (today)` : label
}

function loadLast7Days() {
  NativeModules.HealthModule.getLast7Days((result) => {
    days.value = result
  })
}

function refreshStatus() {
  errorText.value = null
  NativeModules.HealthModule.getAuthorizationStatus((result) => {
    authStatus.value = result.status
    if (result.status === 'granted') {
      loadLast7Days()
    }
  })
}

function onRequestAccess() {
  NativeModules.HealthModule.requestAuthorization((result) => {
    errorText.value = null
    authStatus.value = result.status
    if (result.status === 'granted') {
      loadLast7Days()
    }
  })
}

function onLogSteps() {
  if (logDisabled.value) return
  NativeModules.HealthModule.logSteps(500, (result) => {
    if (result.success) {
      errorText.value = null
      loadLast7Days()
    } else {
      errorText.value = result.error || 'Failed to save steps'
    }
  })
}

function onBack() {
  close()
}

onMounted(refreshStatus)
</script>

<template>
  <scroll-view class="page-scroll" scroll-orientation="vertical">
    <view class="app">
      <view class="card">
        <text class="status">{{ statusText }}</text>
        <view class="primary" @tap="onRequestAccess">
          <text class="primary__text">Request Access</text>
        </view>
        <view :class="['primary', logDisabled ? 'primary--disabled' : '']" @tap="onLogSteps">
          <text class="primary__text">Log 500 Steps</text>
        </view>
      </view>
      <view class="card">
        <text class="card__title">Last 7 Days</text>
        <view v-if="authStatus === 'granted'" class="day-list">
          <view
            v-for="(day, index) in days"
            :key="day.date"
            :class="['day-row', index === 0 ? 'day-row--today' : '']"
          >
            <text :class="['day-row__text', index === 0 ? 'day-row__text--today' : '']">{{ dayText(day, index) }}</text>
          </view>
        </view>
        <text v-else-if="authStatus === 'denied'" class="empty-state">Health access needed</text>
        <text v-else class="empty-state">No data yet</text>
      </view>
      <view class="secondary" @tap="onBack">
        <text class="secondary__text">Back to Home</text>
      </view>
    </view>
  </scroll-view>
</template>
