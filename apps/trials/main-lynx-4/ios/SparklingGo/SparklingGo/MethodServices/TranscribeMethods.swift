// Copyright 2025 The Sparkling Authors. All rights reserved.
// Licensed under the Apache License Version 2.0 that can be found in the
// LICENSE file in the root directory of this source tree.

import Foundation
import Speech
import Lynx
import SparklingMethod

private func speechAccessStatusString(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
    switch status {
    case .authorized:
        return "granted"
    case .denied, .restricted:
        return "denied"
    case .notDetermined:
        return "notRequested"
    @unknown default:
        return "notRequested"
    }
}

private func firePartialTranscript(paramModel: Any, text: String) {
    guard let model = paramModel as? MethodModel, let lynxView = model.context?.pipeContainer as? LynxView else { return }
    lynxView.sendGlobalEvent("speech.partialTranscript", withParams: [["text": text]])
}

@objc(SpeechStatusResultModel)
final class SpeechStatusResultModel: SPKMethodModel {
    var status: String = "notRequested"

    override func toDict() throws -> [String: Any]? {
        return ["status": status]
    }
}

@objc(SpeechTranscribeResultModel)
final class SpeechTranscribeResultModel: SPKMethodModel {
    var text: String = ""

    override func toDict() throws -> [String: Any]? {
        return ["text": text]
    }
}

@objc(SpeechStatusMethod)
public final class SpeechStatusMethod: PipeMethod {
    public override var methodName: String { "speech.getStatus" }
    public override class func methodName() -> String { "speech.getStatus" }

    @objc public override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    @objc public override var resultModelClass: AnyClass { SpeechStatusResultModel.self }

    @objc public override func call(withParamModel paramModel: Any, completionHandler: PipeMethod.CompletionHandlerProtocol) {
        let result = SpeechStatusResultModel()
        result.status = speechAccessStatusString(SpeechRecognitionManager.shared.authorizationStatus())
        completionHandler.handleCompletion(status: .succeeded(), result: result)
    }
}

@objc(SpeechRequestAccessMethod)
public final class SpeechRequestAccessMethod: PipeMethod {
    public override var methodName: String { "speech.requestAccess" }
    public override class func methodName() -> String { "speech.requestAccess" }

    @objc public override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    @objc public override var resultModelClass: AnyClass { SpeechStatusResultModel.self }

    @objc public override func call(withParamModel paramModel: Any, completionHandler: PipeMethod.CompletionHandlerProtocol) {
        SpeechRecognitionManager.shared.requestAuthorization { status in
            let result = SpeechStatusResultModel()
            result.status = speechAccessStatusString(status)
            completionHandler.handleCompletion(status: .succeeded(), result: result)
        }
    }
}

@objc(SpeechTranscribeSampleMethod)
public final class SpeechTranscribeSampleMethod: PipeMethod {
    public override var methodName: String { "speech.transcribeSample" }
    public override class func methodName() -> String { "speech.transcribeSample" }

    @objc public override var paramsModelClass: AnyClass { EmptyMethodModelClass.self }
    @objc public override var resultModelClass: AnyClass { SpeechTranscribeResultModel.self }

    @objc public override func call(withParamModel paramModel: Any, completionHandler: PipeMethod.CompletionHandlerProtocol) {
        SpeechRecognitionManager.shared.transcribeSample(onPartial: { text in
            firePartialTranscript(paramModel: paramModel, text: text)
        }, completion: { result in
            switch result {
            case .success(let text):
                let model = SpeechTranscribeResultModel()
                model.text = text
                completionHandler.handleCompletion(status: .succeeded(), result: model)
            case .failure(let error):
                completionHandler.handleCompletion(status: .failed(message: error.localizedDescription), result: nil)
            }
        })
    }
}
