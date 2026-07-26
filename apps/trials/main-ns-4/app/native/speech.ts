import { knownFolders, path } from '@nativescript/core'

export type SpeechAuthStatus = 'not-requested' | 'granted' | 'denied'

let recognizer: SFSpeechRecognizer | null = null

function getRecognizer(): SFSpeechRecognizer {
    if (!recognizer) {
        recognizer = SFSpeechRecognizer.new()
    }
    return recognizer
}

function toError(error: NSError): Error {
    return new Error(error.localizedDescription)
}

export function getAuthStatus(): SpeechAuthStatus {
    switch (SFSpeechRecognizer.authorizationStatus()) {
        case SFSpeechRecognizerAuthorizationStatus.Authorized:
            return 'granted'
        case SFSpeechRecognizerAuthorizationStatus.Denied:
        case SFSpeechRecognizerAuthorizationStatus.Restricted:
            return 'denied'
        default:
            return 'not-requested'
    }
}

export function requestAuthorization(): Promise<SpeechAuthStatus> {
    return new Promise((resolve) => {
        SFSpeechRecognizer.requestAuthorization(() => {
            resolve(getAuthStatus())
        })
    })
}

export function transcribeSample(onPartial: (text: string) => void): Promise<string> {
    return new Promise((resolve, reject) => {
        const filePath = path.join(knownFolders.currentApp().path, 'assets', 'sample.wav')
        const url = NSURL.fileURLWithPath(filePath)
        const request = new SFSpeechURLRecognitionRequest({ URL: url })
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        getRecognizer().recognitionTaskWithRequestResultHandler(request, (result, error) => {
            if (error) {
                reject(toError(error))
                return
            }
            if (!result) {
                return
            }
            const text = result.bestTranscription.formattedString
            if (result.final) {
                resolve(text)
            } else {
                onPartial(text)
            }
        })
    })
}
