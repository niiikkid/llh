//
//  TranscribeSpeechUseCase.swift
//  llh
//

import Foundation

enum TranscribeSpeechPreflight: Sendable {
    case missingAPIKey
    case emptyAudio
    case ready
}

@MainActor
struct TranscribeSpeechUseCase {
    private let service: SpeechTranscriptionServing

    init(service: SpeechTranscriptionServing) {
        self.service = service
    }

    func preflight(apiKey: String?, audioData: Data) -> TranscribeSpeechPreflight {
        guard apiKey != nil else {
            return .missingAPIKey
        }
        guard !audioData.isEmpty else {
            return .emptyAudio
        }
        return .ready
    }

    func perform(apiKey: String, audioData: Data) async throws -> String {
        switch preflight(apiKey: apiKey, audioData: audioData) {
        case .missingAPIKey:
            throw OpenAIServiceError.invalidTokenFormat
        case .emptyAudio:
            throw OpenAIServiceError.emptyTranscription
        case .ready:
            break
        }

        let text = try await service.transcribeSpeech(
            apiKey: apiKey,
            modelID: SpeechTranscriptionModel.currentOpenAIModelID,
            audioData: audioData,
            filename: "speech.m4a",
            mimeType: "audio/mp4"
        )
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OpenAIServiceError.emptyTranscription
        }
        return trimmed
    }
}
