<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { close } from 'sparkling-navigation'
import { useGlobalEvent } from 'vue-lynx'
import LynxPipe from 'sparkling-method'

import './App.css'

type AccessStatus = 'notRequested' | 'granted' | 'denied'

const accessStatus = ref<AccessStatus>('notRequested')
const errorMessage = ref('')
const isTranscribing = ref(false)
const transcript = ref('')
const completedSeconds = ref<number | null>(null)

let startedAt = 0

const statusLine = computed(() => {
  if (errorMessage.value) return errorMessage.value
  if (isTranscribing.value) return 'Transcribing…'
  if (accessStatus.value === 'granted') return 'Speech access: granted'
  if (accessStatus.value === 'denied') return 'Speech access: denied'
  return 'Speech access: not requested'
})

const canTranscribe = computed(() => accessStatus.value === 'granted' && !isTranscribing.value)

function extractErrorMessage(response: any, fallback: string): string {
  return (response && response.data && response.data.__status_message__) || (response && response.msg) || fallback
}

function goHome() {
  close()
}

function refreshStatus() {
  LynxPipe.call('speech.getStatus', {}, (response: any) => {
    if (response && response.code === 1 && response.data) {
      accessStatus.value = response.data.status
    } else {
      errorMessage.value = extractErrorMessage(response, 'Failed to read speech access status')
    }
  })
}

function requestAccess() {
  errorMessage.value = ''
  LynxPipe.call('speech.requestAccess', {}, (response: any) => {
    if (response && response.code === 1 && response.data) {
      accessStatus.value = response.data.status
    } else {
      errorMessage.value = extractErrorMessage(response, 'Failed to request speech access')
    }
  })
}

function transcribeSample() {
  if (!canTranscribe.value) return
  errorMessage.value = ''
  transcript.value = ''
  completedSeconds.value = null
  isTranscribing.value = true
  startedAt = Date.now()
  LynxPipe.call('speech.transcribe', {}, (response: any) => {
    isTranscribing.value = false
    if (response && response.code === 1 && response.data) {
      transcript.value = response.data.transcript
      completedSeconds.value = (Date.now() - startedAt) / 1000
    } else {
      errorMessage.value = extractErrorMessage(response, 'Failed to transcribe sample')
    }
  })
}

useGlobalEvent('speech.partial', (payload: any) => {
  if (isTranscribing.value && payload && typeof payload.text === 'string') {
    transcript.value = payload.text
  }
})

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
        <text class="title">Transcribe</text>
      </view>
      <text class="status-line">{{ statusLine }}</text>
      <view class="section">
        <view class="button" @tap="requestAccess">
          <text class="button__text">Request Access</text>
        </view>
        <view :class="['button', canTranscribe ? '' : 'button--disabled']" @tap="transcribeSample">
          <text class="button__text">Transcribe Sample</text>
        </view>
      </view>
      <view class="card">
        <text v-if="!transcript" class="empty-state">No transcript yet</text>
        <view v-else>
          <text class="transcript-text">{{ transcript }}</text>
          <text v-if="completedSeconds !== null" class="completed-line">Completed in {{ completedSeconds.toFixed(1) }} s</text>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
