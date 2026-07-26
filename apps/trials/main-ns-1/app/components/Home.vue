<template>
    <Frame>
        <Page>
            <ActionBar title="Native Bench" />

            <StackLayout verticalAlignment="middle" class="p-6">
                <Label text="Native Bench" class="text-3xl font-bold text-center" textWrap="true" />
                <Label text="Token economics benchmark" class="text-base text-gray-500 text-center mt-2" textWrap="true" />

                <Button text="Health" class="mt-10 p-3 text-lg bg-blue-500 text-white rounded" @tap="goToHealth" />
                <Button text="Transcribe" class="mt-4 p-3 text-lg bg-blue-500 text-white rounded" @tap="goToTranscribe" />
            </StackLayout>
        </Page>
    </Frame>
</template>

<script setup lang="ts">
import { $navigateTo } from 'nativescript-vue'
import Health from './Health.vue'
import Transcribe from './Transcribe.vue'

function goToHealth() {
    $navigateTo(Health)
}

function goToTranscribe() {
    $navigateTo(Transcribe)
}
</script>
