<template>
    <Page @navigatedTo="onNavigatedTo">
        <ActionBar title="Transcribe">
            <NavigationButton text="Back" @tap="$navigateBack" />
        </ActionBar>

        <StackLayout class="p-4">
            <Label :text="statusText" class="text-base text-gray-700" textWrap="true" />

            <Button text="Request Access" class="bg-blue-500 text-white rounded-lg py-3 mt-4" @tap="onRequestAccess" />

            <Button text="Transcribe Sample" :isEnabled="canTranscribe"
                :class="canTranscribe ? 'bg-blue-500 text-white rounded-lg py-3 mt-3' : 'bg-gray-300 text-gray-500 rounded-lg py-3 mt-3'"
                @tap="onTranscribe" />

            <Label :text="transcript" class="text-base text-gray-700 mt-8" textWrap="true" />

            <Label v-if="completedSeconds !== null" :text="`Completed in ${completedSeconds.toFixed(1)} s`"
                class="text-sm text-gray-500 mt-2" textWrap="true" />
        </StackLayout>
    </Page>
</template>

<script setup lang="ts">
import { $navigateBack } from 'nativescript-vue'
import { computed, ref } from 'vue'
import { getAuthStatus, requestAuthorization, transcribeSample, type SpeechAuthStatus } from '~/native/speech'

function statusLabel(status: SpeechAuthStatus): string {
    switch (status) {
        case 'granted':
            return 'Speech access: granted'
        case 'denied':
            return 'Speech access: denied'
        default:
            return 'Speech access: not requested'
    }
}

function errorMessage(e: unknown): string {
    return e instanceof Error ? e.message : String(e)
}

const authStatus = ref<SpeechAuthStatus>('not-requested')
const statusText = ref(statusLabel('not-requested'))
const isTranscribing = ref(false)
const transcript = ref('No transcript yet')
const completedSeconds = ref<number | null>(null)

const accessGranted = computed(() => authStatus.value === 'granted')
const canTranscribe = computed(() => accessGranted.value && !isTranscribing.value)

function refreshStatus() {
    authStatus.value = getAuthStatus()
    statusText.value = statusLabel(authStatus.value)
}

async function onRequestAccess() {
    try {
        authStatus.value = await requestAuthorization()
        statusText.value = statusLabel(authStatus.value)
    } catch (e) {
        statusText.value = errorMessage(e)
    }
}

async function onTranscribe() {
    isTranscribing.value = true
    statusText.value = 'Transcribing…'
    completedSeconds.value = null
    const startTime = Date.now()
    try {
        const finalText = await transcribeSample((partial) => {
            transcript.value = partial
        })
        transcript.value = finalText
        completedSeconds.value = (Date.now() - startTime) / 1000
        statusText.value = statusLabel(authStatus.value)
    } catch (e) {
        statusText.value = errorMessage(e)
    } finally {
        isTranscribing.value = false
    }
}

function onNavigatedTo() {
    refreshStatus()
}
</script>
