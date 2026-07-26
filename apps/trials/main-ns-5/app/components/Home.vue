<template>
    <Frame>
        <Page>
            <StackLayout class="p-6" verticalAlignment="middle">
                <Label text="Native Bench" class="text-3xl font-bold text-center" textWrap="true" />
                <Label text="Token economics benchmark" class="text-base text-gray-500 text-center mt-2 mb-10" textWrap="true" />
                <Button text="Health" class="mb-4 bg-blue-500 text-white rounded-lg p-4" @tap="goHealth" />
                <Button text="Transcribe" class="bg-blue-500 text-white rounded-lg p-4" @tap="goTranscribe" />
            </StackLayout>
        </Page>
    </Frame>
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
