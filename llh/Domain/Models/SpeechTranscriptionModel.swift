//
//  SpeechTranscriptionModel.swift
//  llh
//

import Foundation

enum SpeechTranscriptionModel {
    /// Latest OpenAI file-transcription model. Voice is recorded first, then uploaded;
    /// this is not the Realtime / live transcription API.
    static let currentOpenAIModelID = "gpt-transcribe"
}
