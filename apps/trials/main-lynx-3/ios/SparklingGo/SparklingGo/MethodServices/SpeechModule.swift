// Copyright 2025 The Sparkling Authors. All rights reserved.
// Licensed under the Apache License Version 2.0 that can be found in the
// LICENSE file in the root directory of this source tree.

import Foundation
import Speech
import Lynx

@objc(SpeechModule)
final class SpeechModule: NSObject, LynxModule {
    static var name: String { "SpeechModule" }

    static var methodLookup: [String: String] {
        return [
            "getAuthorizationStatus": NSStringFromSelector(#selector(getAuthorizationStatus(_:))),
            "requestAuthorization": NSStringFromSelector(#selector(requestAuthorization(_:))),
            "transcribeSample": NSStringFromSelector(#selector(transcribeSample(_:))),
        ]
    }

    private static let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private static var activeTask: SFSpeechRecognitionTask?

    override init() {
        super.init()
    }

    init(param: Any) {
        super.init()
    }

    @objc func getAuthorizationStatus(_ callback: @escaping LynxCallbackBlock) {
        callback(Self.statusString(for: SFSpeechRecognizer.authorizationStatus()))
    }

    @objc func requestAuthorization(_ callback: @escaping LynxCallbackBlock) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                callback(["status": Self.statusString(for: status)])
            }
        }
    }

    @objc func transcribeSample(_ callback: @escaping LynxCallbackBlock) {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            callback(["event": "error", "error": "Speech access not granted"])
            return
        }
        guard let recognizer = Self.recognizer else {
            callback(["event": "error", "error": "Failed to initialize recognizer"])
            return
        }
        guard recognizer.isAvailable else {
            callback(["event": "error", "error": "Speech recognizer is not currently available"])
            return
        }
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "wav") else {
            callback(["event": "error", "error": "Bundled sample audio not found"])
            return
        }

        Self.activeTask?.cancel()
        Self.activeTask = nil

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true

        Self.activeTask = recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    callback(["event": "error", "error": error.localizedDescription])
                }
                Self.activeTask = nil
                return
            }
            guard let result = result else { return }
            DispatchQueue.main.async {
                callback([
                    "event": result.isFinal ? "final" : "partial",
                    "transcript": result.bestTranscription.formattedString,
                ])
            }
            if result.isFinal {
                Self.activeTask = nil
            }
        }
    }

    private static func statusString(for status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied, .restricted: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }
}
