<template>
    <Page @navigatedTo="refreshStatus">
        <ActionBar title="Transcribe" />
        <ScrollView>
            <StackLayout class="p-6">
                <Label :text="statusText" class="text-base text-gray-600 mb-4" textWrap="true" />
                <Button text="Request Access" class="mb-3 bg-blue-500 text-white rounded-lg p-4" @tap="requestAccess" />
                <Button
                    text="Transcribe Sample"
                    :isEnabled="canTranscribe"
                    :class="canTranscribe ? 'bg-blue-500 text-white' : 'bg-gray-300 text-gray-500'"
                    class="mb-8 rounded-lg p-4"
                    @tap="transcribeSample"
                />
                <Label :text="transcriptText" class="text-gray-700" textWrap="true" />
                <Label v-if="elapsedText" :text="elapsedText" class="text-gray-500 mt-2" textWrap="true" />
            </StackLayout>
        </ScrollView>
    </Page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { Utils, knownFolders, path as fsPath } from '@nativescript/core'

const SFSA_DENIED = 1
const SFSA_RESTRICTED = 2
const SFSA_AUTHORIZED = 3

const statusText = ref('Speech access: not requested')
const accessGranted = ref(false)
const isTranscribing = ref(false)
const transcriptText = ref('No transcript yet')
const elapsedText = ref('')

const canTranscribe = computed(() => accessGranted.value && !isTranscribing.value)

function refreshStatus() {
    const status = SFSpeechRecognizer.authorizationStatus()

    if (status === SFSA_AUTHORIZED) {
        accessGranted.value = true
        if (!isTranscribing.value) {
            statusText.value = 'Speech access: granted'
        }
    } else if (status === SFSA_DENIED || status === SFSA_RESTRICTED) {
        accessGranted.value = false
        statusText.value = 'Speech access: denied'
    } else {
        accessGranted.value = false
        statusText.value = 'Speech access: not requested'
    }
}

function requestAccess() {
    SFSpeechRecognizer.requestAuthorization((_status) => {
        Utils.dispatchToMainThread(() => {
            refreshStatus()
        })
    })
}

function transcribeSample() {
    const samplePath = fsPath.join(knownFolders.currentApp().path, 'assets/sample.wav')
    const url = NSURL.fileURLWithPath(samplePath)
    const recognizer = SFSpeechRecognizer.new()

    if (!recognizer || !recognizer.available) {
        statusText.value = 'Speech error: recognizer unavailable'
        return
    }

    const request = SFSpeechURLRecognitionRequest.alloc().initWithURL(url)
    request.shouldReportPartialResults = true

    isTranscribing.value = true
    statusText.value = 'Transcribing…'
    transcriptText.value = ''
    elapsedText.value = ''
    const startedAt = Date.now()

    recognizer.recognitionTaskWithRequestResultHandler(request, (result, error) => {
        Utils.dispatchToMainThread(() => {
            if (error) {
                isTranscribing.value = false
                statusText.value = `Speech error: ${error.localizedDescription}`
                return
            }
            if (!result) {
                return
            }

            transcriptText.value = result.bestTranscription.formattedString

            if (result.final) {
                isTranscribing.value = false
                const seconds = (Date.now() - startedAt) / 1000
                elapsedText.value = `Completed in ${seconds.toFixed(1)} s`
                statusText.value = 'Speech access: granted'
            }
        })
    })
}
</script>
