<script setup lang="ts">
import { onMounted, ref } from 'vue-lynx';

import './App.css';
import { runAll } from './interop';

const status = ref('starting…');
const resultText = ref('');

onMounted(() => {
  setTimeout(async () => {
    try {
      resultText.value = await runAll((id) => {
        status.value = `running ${id}…`;
      });
      status.value = 'done';
    } catch (err) {
      resultText.value = `INTEROPJSON:{"fw":"lynxjs","error":"${String(err).replace(/"/g, "'")}"}`;
      status.value = 'error';
    }
  }, 500);
});
</script>

<template>
  <view class="app" style="padding: 40px 16px">
    <text style="font-size: 18px">Interop Bench</text>
    <text style="font-size: 14px; color: #666666">{{ status }}</text>
    <text style="font-size: 8px">{{ resultText }}</text>
  </view>
</template>
