<script setup lang="ts">
import { onMounted } from 'vue-lynx'
import * as router from 'sparkling-navigation'

import './App.css'
import sparklingLogo from '../../assets/sparkling_icon.png'

const secondPageScheme = 'hybrid://lynxview_page?bundle=second.lynx.bundle&title=Second%20Page&screen_orientation=portrait'

onMounted(() => {
  console.info('Hello, Sparkling Vue template')
})

function openSecondPage() {
  router.open({ scheme: secondPageScheme }, (result: router.OpenResponse) => {
    console.info('router.open result', JSON.stringify(result))
  })
}
</script>

<template>
  <scroll-view class="page-scroll" scroll-orientation="vertical">
    <view class="app">
      <view class="hero">
        <text class="eyebrow">Sparkling · Vue Lynx</text>
        <image :src="sparklingLogo" class="logo" />
        <text class="title">Sparkling Starter</text>
      </view>
      <view class="card">
        <view class="card__header">
          <text class="card__title">Multi page demo</text>
          <text class="card__tag card__tag--outline">Router</text>
        </view>
        <text class="label">Scheme</text>
        <text class="pill pill--mono">{{ secondPageScheme }}</text>
        <view class="primary" @tap="openSecondPage">
          <text class="primary__text">Open second page</text>
          <text class="primary__icon">→</text>
        </view>
      </view>
    </view>
  </scroll-view>
</template>
