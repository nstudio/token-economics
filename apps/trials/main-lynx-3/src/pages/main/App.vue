<script setup lang="ts">
import * as router from 'sparkling-navigation'

import './App.css'

function openHealth() {
  router.open({ scheme: 'hybrid://lynxview_page?bundle=health.lynx.bundle&title=Health' }, () => {})
}

function openTranscribe() {
  router.open({ scheme: 'hybrid://lynxview_page?bundle=transcribe.lynx.bundle&title=Transcribe' }, () => {})
}
</script>

<template>
  <scroll-view class="page-scroll" scroll-orientation="vertical">
    <view class="app">
      <view class="hero">
        <text class="title">Native Bench</text>
        <text class="subtitle">Token economics benchmark</text>
      </view>
      <view class="nav-buttons">
        <view class="primary" @tap="openHealth">
          <text class="primary__text">Health</text>
        </view>
        <view class="primary" @tap="openTranscribe">
          <text class="primary__text">Transcribe</text>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
