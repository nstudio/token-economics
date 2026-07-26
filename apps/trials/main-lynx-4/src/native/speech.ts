import pipe from 'sparkling-method'

export type SpeechAccessStatus = 'notRequested' | 'granted' | 'denied'

interface PipeRawResponse<T> {
  code: number
  msg?: string
  data?: T & { __status_message__?: string }
}

function callSpeechMethod<T>(method: string): Promise<T> {
  return new Promise((resolve, reject) => {
    pipe.call(`speech.${method}`, {}, (v: unknown) => {
      const response = v as PipeRawResponse<T>
      // LynxPipeStatusCode.succeeded === 1
      if (response?.code === 1) {
        resolve(response.data as T)
      } else {
        reject(new Error(response?.data?.__status_message__ || response?.msg || 'Unknown error'))
      }
    })
  })
}

export function getSpeechStatus(): Promise<SpeechAccessStatus> {
  return callSpeechMethod<{ status: SpeechAccessStatus }>('getStatus').then((data) => data.status)
}

export function requestSpeechAccess(): Promise<SpeechAccessStatus> {
  return callSpeechMethod<{ status: SpeechAccessStatus }>('requestAccess').then((data) => data.status)
}

export function transcribeSample(onPartial: (text: string) => void): Promise<string> {
  return new Promise((resolve, reject) => {
    const onPartialEvent = (event: unknown) => {
      const text = (event as { text?: string } | undefined)?.text
      if (typeof text === 'string') onPartial(text)
    }
    pipe.on('speech.partialTranscript', onPartialEvent)
    pipe.call('speech.transcribeSample', {}, (v: unknown) => {
      pipe.off('speech.partialTranscript', onPartialEvent)
      const response = v as PipeRawResponse<{ text: string }>
      if (response?.code === 1) {
        resolve(response.data?.text ?? '')
      } else {
        reject(new Error(response?.data?.__status_message__ || response?.msg || 'Unknown error'))
      }
    })
  })
}
