<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { close } from 'sparkling-navigation'
import LynxPipe from 'sparkling-method'

import './App.css'

type AccessStatus = 'notRequested' | 'granted' | 'denied'

interface DayEntry {
  date: string
  steps: number
  isToday: boolean
}

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const accessStatus = ref<AccessStatus>('notRequested')
const errorMessage = ref('')
const days = ref<DayEntry[]>([])
const isLogging = ref(false)

const statusLine = computed(() => {
  if (errorMessage.value) return errorMessage.value
  if (accessStatus.value === 'granted') return 'Health access: granted'
  if (accessStatus.value === 'denied') return 'Health access: denied'
  return 'Health access: not requested'
})

const canLog = computed(() => accessStatus.value === 'granted' && !isLogging.value)
const showAccessNeeded = computed(() => accessStatus.value === 'denied')
const showEmpty = computed(() => accessStatus.value !== 'denied' && days.value.length === 0)

function formatThousands(n: number): string {
  return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function formatDayLabel(entry: DayEntry): string {
  const [year, month, day] = entry.date.split('-').map(Number)
  const weekday = WEEKDAYS[new Date(year, month - 1, day).getDay()]
  const label = `${weekday} ${MONTHS[month - 1]} ${day} — ${formatThousands(entry.steps)} steps`
  return entry.isToday ? `${label} (today)` : label
}

function extractErrorMessage(response: any, fallback: string): string {
  return (response && response.data && response.data.__status_message__) || (response && response.msg) || fallback
}

function goHome() {
  close()
}

function loadDays() {
  LynxPipe.call('health.getLastSevenDays', {}, (response: any) => {
    if (response && response.code === 1) {
      days.value = (response.data && response.data.days) || []
    } else {
      errorMessage.value = extractErrorMessage(response, 'Failed to load step history')
    }
  })
}

function refreshStatus() {
  LynxPipe.call('health.getStatus', {}, (response: any) => {
    if (response && response.code === 1 && response.data) {
      accessStatus.value = response.data.status
      if (accessStatus.value === 'granted') {
        loadDays()
      }
    } else {
      errorMessage.value = extractErrorMessage(response, 'Failed to read health access status')
    }
  })
}

function requestAccess() {
  errorMessage.value = ''
  LynxPipe.call('health.requestAccess', {}, (response: any) => {
    if (response && response.code === 1 && response.data) {
      accessStatus.value = response.data.status
      if (accessStatus.value === 'granted') {
        loadDays()
      }
    } else {
      errorMessage.value = extractErrorMessage(response, 'Failed to request health access')
    }
  })
}

function logSteps() {
  if (!canLog.value) return
  isLogging.value = true
  errorMessage.value = ''
  LynxPipe.call('health.logSteps', {}, (response: any) => {
    isLogging.value = false
    if (response && response.code === 1) {
      loadDays()
    } else {
      errorMessage.value = extractErrorMessage(response, 'Failed to log steps')
    }
  })
}

onMounted(() => {
  refreshStatus()
})
</script>

<template>
  <scroll-view class="page-scroll" scroll-orientation="vertical">
    <view class="page">
      <view class="back-link" @tap="goHome">
        <text class="back-link__text">‹ Home</text>
      </view>
      <view class="header">
        <text class="title">Health</text>
      </view>
      <text class="status-line">{{ statusLine }}</text>
      <view class="section">
        <view class="button" @tap="requestAccess">
          <text class="button__text">Request Access</text>
        </view>
        <view :class="['button', canLog ? '' : 'button--disabled']" @tap="logSteps">
          <text class="button__text">Log 500 Steps</text>
        </view>
      </view>
      <view class="section">
        <text class="section-header">Last 7 Days</text>
        <view class="card">
          <text v-if="showAccessNeeded" class="empty-state">Health access needed</text>
          <text v-else-if="showEmpty" class="empty-state">No data yet</text>
          <view v-else>
            <text
              v-for="entry in days"
              :key="entry.date"
              :class="['day-row', entry.isToday ? 'day-row--today' : '']"
            >{{ formatDayLabel(entry) }}</text>
          </view>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
