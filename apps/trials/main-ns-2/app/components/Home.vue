<template>
    <Frame>
        <Page actionBarHidden="true">
            <StackLayout class="p-6 justify-center h-full">
                <Label text="Native Bench" class="text-3xl font-bold text-center mb-1" textWrap="true" />
                <Label text="Token economics benchmark" class="text-base text-gray-500 text-center mb-8" textWrap="true" />

                <Button text="Health" class="text-lg p-4 mb-3 bg-blue-500 text-white rounded-lg" @tap="onHealth" />
                <Button text="Transcribe" class="text-lg p-4 bg-blue-500 text-white rounded-lg" @tap="onTranscribe" />
            </StackLayout>
        </Page>
    </Frame>
</template>

<script setup lang="ts">
import { $navigateTo } from 'nativescript-vue'
import Health from './Health.vue'
import Transcribe from './Transcribe.vue'

function onHealth() {
  $navigateTo(Health)
}

function onTranscribe() {
  $navigateTo(Transcribe)
}
</script>
