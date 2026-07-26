<script setup lang="ts">
import { onMounted, ref } from 'vue-lynx'
import { close } from 'sparkling-navigation'

import './App.css'

const accessStatus = ref<HealthAccessStatus>('notDetermined')
const statusMessage = ref('Health access: not requested')
const days = ref<HealthKitDayEntry[]>([])
const logging = ref(false)

function accessLabel(status: HealthAccessStatus): string {
  if (status === 'authorized') return 'granted'
  if (status === 'denied') return 'denied'
  return 'not requested'
}

function loadLast7Days() {
  NativeModules.HealthKitModule.getLast7Days((result) => {
    days.value = result
  })
}

function refreshStatus() {
  NativeModules.HealthKitModule.getAuthorizationStatus((result) => {
    accessStatus.value = result.status
    statusMessage.value = `Health access: ${accessLabel(result.status)}`
    if (result.status === 'authorized') {
      loadLast7Days()
    }
  })
}

function requestAccess() {
  NativeModules.HealthKitModule.requestAuthorization((result) => {
    accessStatus.value = result.status
    statusMessage.value = result.error ?? `Health access: ${accessLabel(result.status)}`
    if (result.status === 'authorized') {
      loadLast7Days()
    }
  })
}

function logSteps() {
  if (accessStatus.value !== 'authorized' || logging.value) return
  logging.value = true
  NativeModules.HealthKitModule.logSteps(500, (result) => {
    logging.value = false
    if (!result.success) {
      statusMessage.value = result.error ?? 'Failed to log steps'
      return
    }
    loadLast7Days()
  })
}

function goHome() {
  close()
}

onMounted(() => {
  refreshStatus()
})
</script>

<template>
  <scroll-view class="page-scroll" scroll-orientation="vertical">
    <view class="screen">
      <text class="status-line">{{ statusMessage }}</text>
      <view class="button-row">
        <view class="button" @tap="requestAccess">
          <text class="button-text">Request Access</text>
        </view>
        <view :class="['button', { 'button--disabled': accessStatus !== 'authorized' || logging }]" @tap="logSteps">
          <text class="button-text">Log 500 Steps</text>
        </view>
      </view>
      <text class="section-header">Last 7 Days</text>
      <text v-if="accessStatus === 'denied'" class="empty-state">Health access needed</text>
      <text v-else-if="days.length === 0" class="empty-state">No data yet</text>
      <view v-else class="list">
        <view v-for="day in days" :key="day.text" :class="['list-row', { 'list-row--today': day.isToday }]">
          <text class="list-row__day">{{ day.text }}</text>
        </view>
      </view>
      <view class="back-row">
        <view class="button button--secondary" @tap="goHome">
          <text class="button-text">Back to Home</text>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
