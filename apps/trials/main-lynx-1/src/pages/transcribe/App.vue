<script setup lang="ts">
import { close } from 'sparkling-navigation'
import { computed, onMounted, ref, useGlobalEvent } from 'vue-lynx'

import './App.css'

type AuthStatus = 'not_requested' | 'granted' | 'denied'

const authStatus = ref<AuthStatus>('not_requested')
const errorText = ref<string | null>(null)
const isTranscribing = ref(false)
const hasTranscript = ref(false)
const transcript = ref('')
const completedSeconds = ref<number | null>(null)
let startedAt = 0

const statusText = computed(() => {
  if (errorText.value) return errorText.value
  if (isTranscribing.value) return 'Transcribing…'
  if (authStatus.value === 'granted') return 'Speech access: granted'
  if (authStatus.value === 'denied') return 'Speech access: denied'
  return 'Speech access: not requested'
})

const transcribeDisabled = computed(() => authStatus.value !== 'granted' || isTranscribing.value)

function refreshStatus() {
  errorText.value = null
  NativeModules.SpeechModule.getAuthorizationStatus((result) => {
    authStatus.value = result.status
  })
}

function onRequestAccess() {
  NativeModules.SpeechModule.requestAuthorization((result) => {
    errorText.value = null
    authStatus.value = result.status
  })
}

function onTranscribe() {
  if (transcribeDisabled.value) return
  errorText.value = null
  hasTranscript.value = false
  transcript.value = ''
  completedSeconds.value = null
  isTranscribing.value = true
  startedAt = Date.now()
  NativeModules.SpeechModule.transcribeSample()
}

useGlobalEvent('speechPartial', (text) => {
  hasTranscript.value = true
  transcript.value = text as string
})

useGlobalEvent('speechFinal', (result) => {
  isTranscribing.value = false
  const { text, error } = result as { text?: string; error?: string }
  if (error) {
    errorText.value = error
    return
  }
  hasTranscript.value = true
  transcript.value = text ?? ''
  completedSeconds.value = (Date.now() - startedAt) / 1000
})

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
        <view :class="['primary', transcribeDisabled ? 'primary--disabled' : '']" @tap="onTranscribe">
          <text class="primary__text">Transcribe Sample</text>
        </view>
      </view>
      <view class="card">
        <text v-if="hasTranscript" class="result">{{ transcript }}</text>
        <text v-else class="empty-state">No transcript yet</text>
        <text v-if="completedSeconds !== null" class="completed">{{ `Completed in ${completedSeconds.toFixed(1)} s` }}</text>
      </view>
      <view class="secondary" @tap="onBack">
        <text class="secondary__text">Back to Home</text>
      </view>
    </view>
  </scroll-view>
</template>
