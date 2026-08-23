//
//  SpeechTranscriptionServing.swift
//  llh
//

import Foundation

/// Speech-to-text for a completed recording. Always OpenAI, never the text provider.
protocol SpeechTranscriptionServing {
    func transcribeSpeech(
        apiKey: String,
        modelID: String,
        audioData: Data,
        filename: String,
        mimeType: String
    ) async throws -> String
}
