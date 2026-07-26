<template>
    <Frame>
        <Page actionBarHidden="true">
            <GridLayout rows="*, auto, auto, auto, *" class="px-8">
                <StackLayout row="1" class="mb-12">
                    <Label text="Native Bench" class="text-3xl font-bold text-center" textWrap="true" />
                    <Label text="Token economics benchmark" class="text-base text-gray-500 text-center mt-1" textWrap="true" />
                </StackLayout>

                <Button row="2" text="Health" @tap="$navigateTo(Health)"
                    class="bg-blue-500 text-white text-lg rounded-lg py-3" />

                <Button row="3" text="Transcribe" @tap="$navigateTo(Transcribe)"
                    class="bg-blue-500 text-white text-lg rounded-lg py-3 mt-4" />
            </GridLayout>
        </Page>
    </Frame>
</template>

<script setup lang="ts">
import { $navigateTo } from 'nativescript-vue'
import Health from './Health.vue'
import Transcribe from './Transcribe.vue'
</script>
