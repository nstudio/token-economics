<script setup lang="ts">
import { open } from 'sparkling-navigation'
import type { OpenResponse } from 'sparkling-navigation'

import './App.css'

function goTo(bundle: string, title: string) {
  open(
    { scheme: `hybrid://lynxview_page?bundle=${bundle}.lynx.bundle&title=${encodeURIComponent(title)}` },
    (result: OpenResponse) => {
      if (result.code !== 1) {
        console.error(`navigation to ${bundle} failed`, result.msg)
      }
    }
  )
}

function openHealth() {
  goTo('health', 'Health')
}

function openTranscribe() {
  goTo('transcribe', 'Transcribe')
}
</script>

<template>
  <scroll-view class="page-scroll" scroll-orientation="vertical">
    <view class="page">
      <view class="header">
        <text class="title">Native Bench</text>
        <text class="subtitle">Token economics benchmark</text>
      </view>
      <view class="section">
        <view class="button" @tap="openHealth">
          <text class="button__text">Health</text>
        </view>
        <view class="button" @tap="openTranscribe">
          <text class="button__text">Transcribe</text>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
