import Foundation
import Speech
import Lynx

@objc(SpeechModule)
@objcMembers
public final class SpeechModule: NSObject, LynxContextModule {

    public static var name: String { "SpeechModule" }

    public static var methodLookup: [String: String] {
        [
            "getAuthorizationStatus": NSStringFromSelector(#selector(getAuthorizationStatus(_:))),
            "requestAuthorization": NSStringFromSelector(#selector(requestAuthorization(_:))),
            "transcribe": NSStringFromSelector(#selector(transcribe(_:))),
        ]
    }

    private weak var lynxContext: LynxContext?
    private var recognitionTask: SFSpeechRecognitionTask?

    public init(lynxContext: LynxContext) {
        self.lynxContext = lynxContext
        super.init()
    }

    public init(lynxContext: LynxContext, withParam param: Any) {
        self.lynxContext = lynxContext
        super.init()
    }

    public override init() {
        super.init()
    }

    public init(param: Any) {
        super.init()
    }

    private func statusString(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied, .restricted: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    @objc func getAuthorizationStatus(_ callback: @escaping (NSDictionary) -> Void) {
        callback(["status": statusString(SFSpeechRecognizer.authorizationStatus())])
    }

    @objc func requestAuthorization(_ callback: @escaping (NSDictionary) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            callback(["status": self.statusString(status), "error": NSNull()])
        }
    }

    @objc func transcribe(_ callback: @escaping (NSDictionary) -> Void) {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "wav") else {
            callback(["success": false, "transcript": NSNull(), "error": "Sample audio file not found in bundle"])
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            callback(["success": false, "transcript": NSNull(), "error": "Speech recognizer is not available"])
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true

        var didComplete = false
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self, !didComplete else { return }

            if let result = result {
                self.lynxContext?.sendGlobalEvent("speechPartial", withParams: [result.bestTranscription.formattedString])
                if result.isFinal {
                    didComplete = true
                    callback(["success": true, "transcript": result.bestTranscription.formattedString, "error": NSNull()])
                }
            }

            if let error = error {
                didComplete = true
                callback(["success": false, "transcript": NSNull(), "error": error.localizedDescription])
            }
        }
    }
}
