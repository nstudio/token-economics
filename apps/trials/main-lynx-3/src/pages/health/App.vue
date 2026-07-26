<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { close } from 'sparkling-navigation'

import './App.css'

type AuthStatus = 'notDetermined' | 'authorized' | 'denied'

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const authStatus = ref<AuthStatus>('notDetermined')
const statusLine = ref('Health access: not requested')
const listError = ref('')
const days = ref<{ label: string; isToday: boolean }[]>([])

function goHome() {
  close()
}

function statusLabel(status: AuthStatus): string {
  if (status === 'authorized') return 'Health access: granted'
  if (status === 'denied') return 'Health access: denied'
  return 'Health access: not requested'
}

function formatNumber(value: number): string {
  return Math.round(value).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function formatDay(dateMs: number, steps: number, isToday: boolean): string {
  const date = new Date(dateMs)
  const label = `${WEEKDAYS[date.getDay()]} ${MONTHS[date.getMonth()]} ${date.getDate()} — ${formatNumber(steps)} steps`
  return isToday ? `${label} (today)` : label
}

function refreshList() {
  if (authStatus.value !== 'authorized') {
    listError.value = ''
    days.value = []
    return
  }
  NativeModules.HealthKitModule.getLast7Days((result) => {
    if (result.success && result.days) {
      listError.value = ''
      days.value = result.days.map((day) => ({
        label: formatDay(day.dateMs, day.steps, day.isToday),
        isToday: day.isToday,
      }))
    } else {
      listError.value = result.error ?? 'Unable to load step data'
      days.value = []
    }
  })
}

function refreshStatus() {
  NativeModules.HealthKitModule.getAuthorizationStatus((status) => {
    authStatus.value = status as AuthStatus
    statusLine.value = statusLabel(authStatus.value)
    refreshList()
  })
}

function requestAccess() {
  NativeModules.HealthKitModule.requestAuthorization((result) => {
    authStatus.value = result.status as AuthStatus
    statusLine.value = result.error ?? statusLabel(authStatus.value)
    refreshList()
  })
}

function logSteps() {
  if (authStatus.value !== 'authorized') return
  NativeModules.HealthKitModule.logSteps(500, (result) => {
    if (result.success) {
      refreshList()
    } else {
      statusLine.value = result.error ?? 'Failed to log steps'
    }
  })
}

onMounted(() => {
  refreshStatus()
})
</script>

<template>
  <scroll-view class="page-scroll" scroll-orientation="vertical">
    <view class="app">
      <text class="back-link" @tap="goHome">← Home</text>
      <view class="card">
        <text class="status-line">{{ statusLine }}</text>
        <view class="primary" @tap="requestAccess">
          <text class="primary__text">Request Access</text>
        </view>
        <view :class="['primary', authStatus !== 'authorized' && 'primary--disabled']" @tap="logSteps">
          <text class="primary__text">Log 500 Steps</text>
        </view>
        <text class="section-header">Last 7 Days</text>
        <text v-if="authStatus !== 'authorized'" class="empty-state">Health access needed</text>
        <text v-else-if="listError" class="empty-state">{{ listError }}</text>
        <view
          v-for="(day, index) in days"
          :key="index"
          :class="['list-row', day.isToday && 'list-row--today']"
        >
          <text class="list-row__label">{{ day.label }}</text>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
