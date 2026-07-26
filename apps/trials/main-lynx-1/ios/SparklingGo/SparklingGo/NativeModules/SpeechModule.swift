// Copyright 2025 The Sparkling Authors. All rights reserved.
// Licensed under the Apache License Version 2.0 that can be found in the
// LICENSE file in the root directory of this source tree.

import Foundation
import Speech
import Lynx

@objc(SpeechModule)
@objcMembers
public class SpeechModule: NSObject, LynxContextModule {
    public static var name: String { "SpeechModule" }

    public static var methodLookup: [String: String] {
        return [
            "getAuthorizationStatus": NSStringFromSelector(#selector(getAuthorizationStatus(_:))),
            "requestAuthorization": NSStringFromSelector(#selector(requestAuthorization(_:))),
            "transcribeSample": NSStringFromSelector(#selector(transcribeSample)),
        ]
    }

    private weak var context: LynxContext?
    private var recognitionTask: SFSpeechRecognitionTask?

    public required init(lynxContext context: LynxContext) {
        self.context = context
        super.init()
    }

    public required init(lynxContext context: LynxContext, withParam param: Any) {
        self.context = context
        super.init()
    }

    public required init(param: Any) {
        super.init()
    }

    public override required init() {
        super.init()
    }

    private func currentStatus() -> String {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: return "not_requested"
        case .authorized: return "granted"
        case .denied, .restricted: return "denied"
        @unknown default: return "denied"
        }
    }

    func getAuthorizationStatus(_ callback: @escaping (NSDictionary) -> Void) {
        callback(["status": currentStatus()])
    }

    func requestAuthorization(_ callback: @escaping (NSDictionary) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] _ in
            let status = self?.currentStatus() ?? "denied"
            DispatchQueue.main.async {
                callback(["status": status])
            }
        }
    }

    func transcribeSample() {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "wav") else {
            sendFinal(text: nil, error: "Could not locate sample audio in the app bundle")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
            sendFinal(text: nil, error: "Speech recognizer is unavailable")
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true

        recognitionTask?.cancel()
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.sendFinal(text: nil, error: error.localizedDescription)
                }
                return
            }
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            DispatchQueue.main.async {
                if result.isFinal {
                    self.sendFinal(text: text, error: nil)
                } else {
                    self.context?.sendGlobalEvent("speechPartial", withParams: [text])
                }
            }
        }
    }

    private func sendFinal(text: String?, error: String?) {
        var payload: [String: Any] = [:]
        if let text { payload["text"] = text }
        if let error { payload["error"] = error }
        context?.sendGlobalEvent("speechFinal", withParams: [payload as NSDictionary])
    }
}
