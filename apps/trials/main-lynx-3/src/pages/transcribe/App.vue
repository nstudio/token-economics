<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { close } from 'sparkling-navigation'

import './App.css'

type AuthStatus = 'notDetermined' | 'authorized' | 'denied'

const authStatus = ref<AuthStatus>('notDetermined')
const statusLine = ref('Speech access: not requested')
const isTranscribing = ref(false)
const transcript = ref('')
const completedIn = ref<number | null>(null)

let startedAtMs = 0

function goHome() {
  close()
}

function statusLabel(status: AuthStatus): string {
  if (status === 'authorized') return 'Speech access: granted'
  if (status === 'denied') return 'Speech access: denied'
  return 'Speech access: not requested'
}

function refreshStatus() {
  NativeModules.SpeechModule.getAuthorizationStatus((status) => {
    authStatus.value = status as AuthStatus
    statusLine.value = statusLabel(authStatus.value)
  })
}

function requestAccess() {
  NativeModules.SpeechModule.requestAuthorization((result) => {
    authStatus.value = result.status as AuthStatus
    statusLine.value = result.error ?? statusLabel(authStatus.value)
  })
}

function transcribeSample() {
  if (authStatus.value !== 'authorized' || isTranscribing.value) return
  isTranscribing.value = true
  transcript.value = ''
  completedIn.value = null
  statusLine.value = 'Transcribing…'
  startedAtMs = Date.now()
  NativeModules.SpeechModule.transcribeSample((result) => {
    if (result.event === 'error') {
      isTranscribing.value = false
      statusLine.value = result.error ?? 'Transcription failed'
      return
    }
    transcript.value = result.transcript ?? ''
    if (result.event === 'final') {
      isTranscribing.value = false
      completedIn.value = (Date.now() - startedAtMs) / 1000
      statusLine.value = statusLabel(authStatus.value)
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
        <view
          :class="['primary', (authStatus !== 'authorized' || isTranscribing) && 'primary--disabled']"
          @tap="transcribeSample"
        >
          <text class="primary__text">Transcribe Sample</text>
        </view>
        <text v-if="!transcript" class="empty-state">No transcript yet</text>
        <text v-else class="result">{{ transcript }}</text>
        <text v-if="completedIn !== null" class="result__meta">Completed in {{ completedIn.toFixed(1) }} s</text>
      </view>
    </view>
  </scroll-view>
</template>
