<template>
    <Page @navigatedTo="onNavigatedTo">
        <ActionBar title="Transcribe" />

        <StackLayout class="p-6">
            <Label :text="statusText" class="text-base text-gray-600 mb-4" textWrap="true" />

            <Button text="Request Access" class="text-base bg-blue-500 text-white p-3 rounded-lg mb-2" @tap="requestAccess" />
            <Button text="Transcribe Sample" :isEnabled="canTranscribe" :class="transcribeButtonClass" @tap="transcribeSample" />

            <Label v-if="!transcript" text="No transcript yet" class="text-base text-gray-400" textWrap="true" />
            <StackLayout v-else>
                <Label :text="transcript" class="text-base text-gray-800" textWrap="true" />
                <Label v-if="completedText" :text="completedText" class="text-sm text-gray-500 mt-1" textWrap="true" />
            </StackLayout>
        </StackLayout>
    </Page>
</template>

<script setup lang="ts">
import { Utils, knownFolders } from '@nativescript/core'
import { computed, ref } from 'vue'

// Ambient `const enum`s from the iOS type defs aren't inlined by esbuild across files,
// so reference SFSpeechRecognizer's underlying integer values directly instead of the enum names.
const SF_AUTH_NOT_DETERMINED = 0
const SF_AUTH_DENIED = 1
const SF_AUTH_RESTRICTED = 2
const SF_AUTH_AUTHORIZED = 3

const recognizer = new SFSpeechRecognizer({ locale: NSLocale.alloc().initWithLocaleIdentifier('en-US') })

const statusText = ref('Speech access: not requested')
const granted = ref(false)
const isRunning = ref(false)
const transcript = ref('')
const completedText = ref('')

const canTranscribe = computed(() => granted.value && !isRunning.value)

const transcribeButtonClass = computed(() =>
  canTranscribe.value ? 'text-base bg-blue-500 text-white p-3 rounded-lg mb-6' : 'text-base bg-gray-300 text-gray-500 p-3 rounded-lg mb-6'
)

function refreshStatus() {
  const status = SFSpeechRecognizer.authorizationStatus()

  if (status === SF_AUTH_AUTHORIZED) {
    statusText.value = 'Speech access: granted'
    granted.value = true
  } else if (status === SF_AUTH_DENIED || status === SF_AUTH_RESTRICTED) {
    statusText.value = 'Speech access: denied'
    granted.value = false
  } else {
    statusText.value = 'Speech access: not requested'
    granted.value = false
  }
}

function requestAccess() {
  SFSpeechRecognizer.requestAuthorization(() => {
    Utils.dispatchToMainThread(() => {
      refreshStatus()
    })
  })
}

function transcribeSample() {
  if (!canTranscribe.value) return

  if (!recognizer.available) {
    statusText.value = 'Speech recognizer is not available'
    return
  }

  transcript.value = ''
  completedText.value = ''
  isRunning.value = true
  statusText.value = 'Transcribing…'

  const startedAt = Date.now()
  const path = `${knownFolders.currentApp().path}/assets/sample.wav`
  const request = new SFSpeechURLRecognitionRequest({ URL: NSURL.fileURLWithPath(path) })
  request.shouldReportPartialResults = true

  recognizer.recognitionTaskWithRequestResultHandler(request, (result, error) => {
    Utils.dispatchToMainThread(() => {
      if (error) {
        isRunning.value = false
        statusText.value = error.localizedDescription
        return
      }
      if (!result) return

      transcript.value = result.bestTranscription.formattedString

      if (result.final) {
        isRunning.value = false
        statusText.value = 'Speech access: granted'
        const elapsedSeconds = (Date.now() - startedAt) / 1000
        completedText.value = `Completed in ${elapsedSeconds.toFixed(1)} s`
      }
    })
  })
}

function onNavigatedTo() {
  refreshStatus()
}
</script>
