<template>
    <Page>
        <ActionBar title="Native Bench" />

        <StackLayout class="p-6" verticalAlignment="middle">
            <Label text="Native Bench" class="text-3xl font-bold text-center text-gray-800" textWrap="true" />
            <Label text="Token economics benchmark" class="text-base text-center text-gray-500 mb-8" textWrap="true" />

            <Button text="Health" class="text-lg bg-blue-500 text-white p-4 rounded-lg mb-3" @tap="goHealth" />
            <Button text="Transcribe" class="text-lg bg-blue-500 text-white p-4 rounded-lg" @tap="goTranscribe" />
        </StackLayout>
    </Page>
</template>

<script setup lang="ts">
  import { $navigateTo } from 'nativescript-vue'
  import Health from './Health.vue'
  import Transcribe from './Transcribe.vue'

  function goHealth() {
    $navigateTo(Health)
  }

  function goTranscribe() {
    $navigateTo(Transcribe)
  }
</script>
