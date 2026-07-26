import { knownFolders } from '@nativescript/core'

export type AuthStatus = 'not-requested' | 'granted' | 'denied'

function toAuthStatus(status: SFSpeechRecognizerAuthorizationStatus): AuthStatus {
    switch (status) {
        case SFSpeechRecognizerAuthorizationStatus.Authorized:
            return 'granted'
        case SFSpeechRecognizerAuthorizationStatus.Denied:
        case SFSpeechRecognizerAuthorizationStatus.Restricted:
            return 'denied'
        default:
            return 'not-requested'
    }
}

export function getAuthStatus(): AuthStatus {
    return toAuthStatus(SFSpeechRecognizer.authorizationStatus())
}

export function requestAccess(): Promise<AuthStatus> {
    return new Promise((resolve) => {
        SFSpeechRecognizer.requestAuthorization((status) => {
            resolve(toAuthStatus(status))
        })
    })
}

export function transcribeSample(onPartial: (text: string) => void): Promise<string> {
    return new Promise((resolve, reject) => {
        const filePath = `${knownFolders.currentApp().path}/assets/sample.wav`
        const url = NSURL.fileURLWithPath(filePath)
        const recognizer = SFSpeechRecognizer.new()
        const request = SFSpeechURLRecognitionRequest.alloc().initWithURL(url)
        request.shouldReportPartialResults = true

        recognizer.recognitionTaskWithRequestResultHandler(request, (result, error) => {
            if (error) {
                reject(new Error(error.localizedDescription))
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
