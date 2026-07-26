<script setup lang="ts">
import * as router from 'sparkling-navigation'

import './App.css'

function openHealth() {
  router.open(
    { scheme: 'hybrid://lynxview_page?bundle=health.lynx.bundle&title=Health&screen_orientation=portrait' },
    () => {},
  )
}

function openTranscribe() {
  router.open(
    { scheme: 'hybrid://lynxview_page?bundle=transcribe.lynx.bundle&title=Transcribe&screen_orientation=portrait' },
    () => {},
  )
}
</script>

<template>
  <scroll-view class="page-scroll" scroll-orientation="vertical">
    <view class="screen">
      <view class="screen-header">
        <text class="screen-title">Native Bench</text>
        <text class="screen-subtitle">Token economics benchmark</text>
      </view>
      <view class="button-row">
        <view class="button" @tap="openHealth">
          <text class="button-text">Health</text>
        </view>
        <view class="button" @tap="openTranscribe">
          <text class="button-text">Transcribe</text>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
