import Foundation
import Speech

enum SpeechManagerError: LocalizedError {
    case fileNotFound
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Sample audio file not found in the app bundle"
        case .recognizerUnavailable:
            return "Speech recognizer is not available on this device"
        }
    }
}

final class SpeechManager {
    static let shared = SpeechManager()

    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?

    private init() {}

    var currentStatus: String {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            return "notRequested"
        case .authorized:
            return "granted"
        case .denied, .restricted:
            return "denied"
        @unknown default:
            return "notRequested"
        }
    }

    func requestAccess(completion: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                completion(self.currentStatus)
            }
        }
    }

    func transcribeSample(onPartial: @escaping (String) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "wav") else {
            completion(.failure(SpeechManagerError.fileNotFound))
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            completion(.failure(SpeechManagerError.recognizerUnavailable))
            return
        }
        self.recognizer = recognizer

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        var didFinish = false
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            DispatchQueue.main.async {
                if didFinish { return }
                if let error {
                    didFinish = true
                    completion(.failure(error))
                    return
                }
                guard let result else { return }
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    didFinish = true
                    completion(.success(text))
                } else {
                    onPartial(text)
                }
            }
        }
    }
}
