<script setup lang="ts">
import * as router from 'sparkling-navigation'

import './App.css'

const healthScheme = 'hybrid://lynxview_page?bundle=health.lynx.bundle&title=Health&screen_orientation=portrait'
const transcribeScheme = 'hybrid://lynxview_page?bundle=transcribe.lynx.bundle&title=Transcribe&screen_orientation=portrait'

function openHealth() {
  router.open({ scheme: healthScheme }, (result: router.OpenResponse) => {
    console.info('router.open result', JSON.stringify(result))
  })
}

function openTranscribe() {
  router.open({ scheme: transcribeScheme }, (result: router.OpenResponse) => {
    console.info('router.open result', JSON.stringify(result))
  })
}
</script>

<template>
  <scroll-view class="page-scroll" scroll-orientation="vertical">
    <view class="app">
      <view class="hero">
        <text class="title">Native Bench</text>
        <text class="subtitle">Token economics benchmark</text>
      </view>
      <view class="card">
        <view class="primary" @tap="openHealth">
          <text class="primary__text">Health</text>
          <text class="primary__icon">→</text>
        </view>
        <view class="primary" @tap="openTranscribe">
          <text class="primary__text">Transcribe</text>
          <text class="primary__icon">→</text>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
