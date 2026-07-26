<script setup lang="ts">
import { ref, computed, onMounted } from 'vue-lynx'
import { close } from 'sparkling-navigation'
import { getSpeechStatus, requestSpeechAccess, transcribeSample } from '../../native/speech'
import type { SpeechAccessStatus } from '../../native/speech'

import './App.css'

const STATUS_TEXT: Record<SpeechAccessStatus, string> = {
  notRequested: 'Speech access: not requested',
  granted: 'Speech access: granted',
  denied: 'Speech access: denied',
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Unknown error'
}

const accessStatus = ref<SpeechAccessStatus>('notRequested')
const statusLine = ref(STATUS_TEXT.notRequested)
const transcript = ref('')
const hasTranscript = ref(false)
const completedLine = ref('')
const transcribing = ref(false)

const canTranscribe = computed(() => accessStatus.value === 'granted' && !transcribing.value)

async function refreshStatus() {
  try {
    accessStatus.value = await getSpeechStatus()
    statusLine.value = STATUS_TEXT[accessStatus.value]
  } catch (error) {
    statusLine.value = errorMessage(error)
  }
}

async function onRequestAccess() {
  try {
    accessStatus.value = await requestSpeechAccess()
    statusLine.value = STATUS_TEXT[accessStatus.value]
  } catch (error) {
    statusLine.value = errorMessage(error)
  }
}

async function onTranscribe() {
  if (!canTranscribe.value) return
  transcribing.value = true
  statusLine.value = 'Transcribing…'
  transcript.value = ''
  hasTranscript.value = false
  completedLine.value = ''
  const startTime = Date.now()
  try {
    const text = await transcribeSample((partial) => {
      transcript.value = partial
      hasTranscript.value = true
    })
    transcript.value = text
    hasTranscript.value = true
    completedLine.value = `Completed in ${((Date.now() - startTime) / 1000).toFixed(1)} s`
    statusLine.value = STATUS_TEXT[accessStatus.value]
  } catch (error) {
    statusLine.value = errorMessage(error)
  } finally {
    transcribing.value = false
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
        <text class="title">Transcribe</text>
      </view>
      <view class="card">
        <text class="status-line">{{ statusLine }}</text>
        <view class="primary" @tap="onRequestAccess">
          <text class="primary__text">Request Access</text>
        </view>
        <view class="primary" :class="{ 'primary--disabled': !canTranscribe }" @tap="onTranscribe">
          <text class="primary__text">Transcribe Sample</text>
        </view>
        <view class="transcript-area">
          <text v-if="!hasTranscript">No transcript yet</text>
          <view v-else>
            <text class="transcript-area__text">{{ transcript }}</text>
            <text v-if="completedLine" class="completed-line">{{ completedLine }}</text>
          </view>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
