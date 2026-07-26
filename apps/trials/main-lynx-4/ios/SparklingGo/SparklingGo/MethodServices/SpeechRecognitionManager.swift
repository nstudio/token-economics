// Copyright 2025 The Sparkling Authors. All rights reserved.
// Licensed under the Apache License Version 2.0 that can be found in the
// LICENSE file in the root directory of this source tree.

import Foundation
import Speech

final class SpeechRecognitionManager: NSObject {
    static let shared = SpeechRecognitionManager()

    private let recognizer = SFSpeechRecognizer()
    private var task: SFSpeechRecognitionTask?

    private override init() {
        super.init()
    }

    func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization(completion: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status)
            }
        }
    }

    func transcribeSample(onPartial: @escaping (String) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        guard task == nil else {
            completion(.failure(NSError(domain: "SpeechRecognitionManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "A transcription is already running"
            ])))
            return
        }
        guard let recognizer = recognizer, recognizer.isAvailable else {
            completion(.failure(NSError(domain: "SpeechRecognitionManager", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Speech recognizer is not available"
            ])))
            return
        }
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "wav") else {
            completion(.failure(NSError(domain: "SpeechRecognitionManager", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "sample.wav not found in app bundle"
            ])))
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        // The iOS Simulator's on-device recognizer fails to initialize (kAFAssistantErrorDomain 1101);
        // force the server-based path, which works on both simulator and device.
        request.requiresOnDeviceRecognition = false

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error = error {
                self?.task = nil
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            guard let result = result else { return }
            let text = result.bestTranscription.formattedString
            if result.isFinal {
                self?.task = nil
                DispatchQueue.main.async {
                    completion(.success(text))
                }
            } else {
                DispatchQueue.main.async {
                    onPartial(text)
                }
            }
        }
    }
}
