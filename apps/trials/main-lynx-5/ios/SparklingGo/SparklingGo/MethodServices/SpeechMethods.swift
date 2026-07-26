import Foundation
import Lynx
import SparklingMethod

@objc(SpeechStatusResult)
final class SpeechStatusResult: SPKMethodModel {
    @objc var status: String = ""

    override class func jsonKeyPathsByPropertyKey() -> [AnyHashable: Any] {
        return ["status": "status"]
    }
}

@objc(SpeechTranscribeResult)
final class SpeechTranscribeResult: SPKMethodModel {
    @objc var transcript: String = ""

    override class func jsonKeyPathsByPropertyKey() -> [AnyHashable: Any] {
        return ["transcript": "transcript"]
    }
}

final class SpeechGetStatusMethod: PipeMethod {
    override class func methodName() -> String { "speech.getStatus" }
    override var methodName: String { "speech.getStatus" }
    override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    override var resultModelClass: AnyClass { SpeechStatusResult.self }

    override func call(withParamModel paramModel: Any, completionHandler: CompletionHandlerProtocol) {
        let result = SpeechStatusResult()
        result.status = SpeechManager.shared.currentStatus
        completionHandler.handleCompletion(status: .succeeded(), result: result)
    }
}

final class SpeechRequestAccessMethod: PipeMethod {
    override class func methodName() -> String { "speech.requestAccess" }
    override var methodName: String { "speech.requestAccess" }
    override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    override var resultModelClass: AnyClass { SpeechStatusResult.self }

    override func call(withParamModel paramModel: Any, completionHandler: CompletionHandlerProtocol) {
        SpeechManager.shared.requestAccess { status in
            let result = SpeechStatusResult()
            result.status = status
            completionHandler.handleCompletion(status: .succeeded(), result: result)
        }
    }
}

final class SpeechTranscribeMethod: PipeMethod {
    override class func methodName() -> String { "speech.transcribe" }
    override var methodName: String { "speech.transcribe" }
    override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    override var resultModelClass: AnyClass { SpeechTranscribeResult.self }

    override func call(withParamModel paramModel: Any, completionHandler: CompletionHandlerProtocol) {
        guard let model = paramModel as? EmptyMethodModelClass, let lynxView = model.context?.pipeContainer as? LynxView else {
            completionHandler.handleCompletion(status: .failed(message: "Unable to access the page context"), result: nil)
            return
        }
        SpeechManager.shared.transcribeSample(
            onPartial: { text in
                lynxView.sendGlobalEvent("speech.partial", withParams: [["text": text]])
            },
            completion: { outcome in
                switch outcome {
                case .success(let text):
                    let result = SpeechTranscribeResult()
                    result.transcript = text
                    completionHandler.handleCompletion(status: .succeeded(), result: result)
                case .failure(let error):
                    completionHandler.handleCompletion(status: .failed(message: error.localizedDescription), result: nil)
                }
            }
        )
    }
}
