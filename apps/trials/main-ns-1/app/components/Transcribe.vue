<template>
    <Page @navigatedTo="onNavigatedTo">
        <ActionBar title="Transcribe" />

        <StackLayout class="p-6">
            <Label :text="statusText" class="text-base" textWrap="true" />

            <Button text="Request Access" class="mt-4 p-3 bg-blue-500 text-white rounded" @tap="onRequestAccess" />
            <Button
                text="Transcribe Sample"
                :isEnabled="canTranscribe"
                :class="canTranscribe ? 'mt-2 p-3 bg-blue-500 text-white rounded' : 'mt-2 p-3 bg-gray-300 text-white rounded'"
                @tap="onTranscribe"
            />

            <Label v-if="!transcript" text="No transcript yet" class="text-gray-500 mt-8" textWrap="true" />
            <StackLayout v-else class="mt-8">
                <Label :text="transcript" textWrap="true" />
                <Label v-if="completedIn" :text="`Completed in ${completedIn} s`" class="text-gray-500 mt-1" textWrap="true" />
            </StackLayout>
        </StackLayout>
    </Page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import * as Speech from '../speech'
import type { AuthStatus } from '../speech'

const statusText = ref('Speech access: not requested')
const access = ref<AuthStatus>('not-requested')
const isRunning = ref(false)
const transcript = ref('')
const completedIn = ref<string | null>(null)

const canTranscribe = computed(() => access.value === 'granted' && !isRunning.value)

function statusLabel(state: AuthStatus): string {
    if (state === 'granted') return 'Speech access: granted'
    if (state === 'denied') return 'Speech access: denied'
    return 'Speech access: not requested'
}

function refreshStatus() {
    access.value = Speech.getAuthStatus()
    statusText.value = statusLabel(access.value)
}

function onNavigatedTo() {
    refreshStatus()
}

async function onRequestAccess() {
    try {
        access.value = await Speech.requestAccess()
        statusText.value = statusLabel(access.value)
    } catch (error) {
        statusText.value = (error as Error).message
    }
}

async function onTranscribe() {
    isRunning.value = true
    completedIn.value = null
    transcript.value = ''
    statusText.value = 'Transcribing…'
    const startTime = Date.now()
    try {
        const final = await Speech.transcribeSample((partial) => {
            transcript.value = partial
        })
        transcript.value = final
        completedIn.value = ((Date.now() - startTime) / 1000).toFixed(1)
        statusText.value = statusLabel(access.value)
    } catch (error) {
        statusText.value = (error as Error).message
    } finally {
        isRunning.value = false
    }
}
</script>
