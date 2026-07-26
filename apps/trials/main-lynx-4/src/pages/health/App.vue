<script setup lang="ts">
import { ref, computed, onMounted } from 'vue-lynx'
import { close } from 'sparkling-navigation'
import { getHealthStatus, requestHealthAccess, logSteps, getLastSevenDays } from '../../native/health'
import type { HealthAccessStatus, HealthDay } from '../../native/health'

import './App.css'

const WEEKDAY_ABBR = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTH_ABBR = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const STATUS_TEXT: Record<HealthAccessStatus, string> = {
  notRequested: 'Health access: not requested',
  granted: 'Health access: granted',
  denied: 'Health access: denied',
}

function formatThousands(value: number): string {
  const sign = value < 0 ? '-' : ''
  const digits = Math.abs(Math.trunc(value)).toString()
  return sign + digits.replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function dayLabel(day: HealthDay, isToday: boolean): string {
  const weekday = WEEKDAY_ABBR[day.weekday - 1] ?? ''
  const month = MONTH_ABBR[day.month - 1] ?? ''
  const suffix = isToday ? ' (today)' : ''
  return `${weekday} ${month} ${day.day} — ${formatThousands(day.steps)} steps${suffix}`
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Unknown error'
}

const accessStatus = ref<HealthAccessStatus>('notRequested')
const statusLine = ref(STATUS_TEXT.notRequested)
const days = ref<HealthDay[]>([])
const daysLoaded = ref(false)
const loggingSteps = ref(false)

const canLogSteps = computed(() => accessStatus.value === 'granted' && !loggingSteps.value)

async function refreshDays() {
  try {
    days.value = await getLastSevenDays()
    daysLoaded.value = true
  } catch (error) {
    statusLine.value = errorMessage(error)
  }
}

async function refreshStatus() {
  try {
    accessStatus.value = await getHealthStatus()
    statusLine.value = STATUS_TEXT[accessStatus.value]
  } catch (error) {
    statusLine.value = errorMessage(error)
    return
  }
  if (accessStatus.value === 'granted') {
    await refreshDays()
  }
}

async function onRequestAccess() {
  try {
    accessStatus.value = await requestHealthAccess()
    statusLine.value = STATUS_TEXT[accessStatus.value]
  } catch (error) {
    statusLine.value = errorMessage(error)
    return
  }
  if (accessStatus.value === 'granted') {
    await refreshDays()
  }
}

async function onLogSteps() {
  if (!canLogSteps.value) return
  loggingSteps.value = true
  try {
    await logSteps()
    statusLine.value = STATUS_TEXT[accessStatus.value]
    await refreshDays()
  } catch (error) {
    statusLine.value = errorMessage(error)
  } finally {
    loggingSteps.value = false
  }
}

function onBack() {
  close()
}

onMounted(() => {
  refreshStatus()
})
</script>

<template>
  <scroll-view class="page-scroll" scroll-orientation="vertical">
    <view class="app">
      <view class="back" @tap="onBack">
        <text class="back__text">← Home</text>
      </view>
      <view class="hero">
        <text class="title">Health</text>
      </view>
      <view class="card">
        <text class="status-line">{{ statusLine }}</text>
        <view class="primary" @tap="onRequestAccess">
          <text class="primary__text">Request Access</text>
        </view>
        <view class="primary" :class="{ 'primary--disabled': !canLogSteps }" @tap="onLogSteps">
          <text class="primary__text">Log 500 Steps</text>
        </view>
        <text class="section-header">Last 7 Days</text>
        <view v-if="accessStatus === 'denied'" class="empty-state">
          <text>Health access needed</text>
        </view>
        <view v-else-if="accessStatus !== 'granted' || !daysLoaded" class="empty-state">
          <text>No data yet</text>
        </view>
        <view v-else class="days-list">
          <view
            v-for="(day, index) in days"
            :key="`${day.year}-${day.month}-${day.day}`"
            class="day-row"
            :class="{ 'day-row--today': index === 0 }"
          >
            <text class="day-row__text">{{ dayLabel(day, index === 0) }}</text>
          </view>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
