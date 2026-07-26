<script setup lang="ts">
import { onMounted, ref, useGlobalEvent } from 'vue-lynx'
import { close } from 'sparkling-navigation'

import './App.css'

const accessStatus = ref<SpeechAccessStatus>('notDetermined')
const statusMessage = ref('Speech access: not requested')
const transcript = ref('')
const completedLine = ref('')
const transcribing = ref(false)

let startTime = 0

function accessLabel(status: SpeechAccessStatus): string {
  if (status === 'authorized') return 'granted'
  if (status === 'denied') return 'denied'
  return 'not requested'
}

function refreshStatus() {
  NativeModules.SpeechModule.getAuthorizationStatus((result) => {
    accessStatus.value = result.status
    statusMessage.value = `Speech access: ${accessLabel(result.status)}`
  })
}

function requestAccess() {
  NativeModules.SpeechModule.requestAuthorization((result) => {
    accessStatus.value = result.status
    statusMessage.value = result.error ?? `Speech access: ${accessLabel(result.status)}`
  })
}

function transcribeSample() {
  if (accessStatus.value !== 'authorized' || transcribing.value) return
  transcribing.value = true
  transcript.value = ''
  completedLine.value = ''
  statusMessage.value = 'Transcribing…'
  startTime = Date.now()
  NativeModules.SpeechModule.transcribe((result) => {
    transcribing.value = false
    if (!result.success) {
      statusMessage.value = result.error ?? 'Transcription failed'
      return
    }
    transcript.value = result.transcript ?? ''
    statusMessage.value = `Speech access: ${accessLabel(accessStatus.value)}`
    completedLine.value = `Completed in ${((Date.now() - startTime) / 1000).toFixed(1)} s`
  })
}

function goHome() {
  close()
}

useGlobalEvent('speechPartial', (text) => {
  if (transcribing.value) {
    transcript.value = text as string
  }
})

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
        <view
          :class="['button', { 'button--disabled': accessStatus !== 'authorized' || transcribing }]"
          @tap="transcribeSample"
        >
          <text class="button-text">Transcribe Sample</text>
        </view>
      </view>
      <view class="transcript-area">
        <text v-if="!transcript" class="transcript-text">No transcript yet</text>
        <text v-else class="transcript-text">{{ transcript }}</text>
        <text v-if="completedLine" class="transcript-meta">{{ completedLine }}</text>
      </view>
      <view class="back-row">
        <view class="button button--secondary" @tap="goHome">
          <text class="button-text">Back to Home</text>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
