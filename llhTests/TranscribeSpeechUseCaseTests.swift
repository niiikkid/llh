//
//  TranscribeSpeechUseCaseTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

private final class FakeSpeechTranscriptionServing: SpeechTranscriptionServing {
    var textToReturn = "привет"
    var errorToThrow: Error?
    private(set) var lastModelID: String?
    private(set) var lastFilename: String?
    private(set) var lastAudioData: Data?

    func transcribeSpeech(
        apiKey: String,
        modelID: String,
        audioData: Data,
        filename: String,
        mimeType: String
    ) async throws -> String {
        lastModelID = modelID
        lastFilename = filename
        lastAudioData = audioData
        if let errorToThrow {
            throw errorToThrow
        }
        return textToReturn
    }
}

struct TranscribeSpeechUseCaseTests {
    @Test
    @MainActor
    func preflight_requiresAPIKeyAndAudio() {
        let useCase = TranscribeSpeechUseCase(service: FakeSpeechTranscriptionServing())

        #expect(useCase.preflight(apiKey: nil, audioData: Data("abc".utf8)) == .missingAPIKey)
        #expect(useCase.preflight(apiKey: "sk-test", audioData: Data()) == .emptyAudio)
        #expect(useCase.preflight(apiKey: "sk-test", audioData: Data("abc".utf8)) == .ready)
    }

    @Test
    @MainActor
    func perform_usesCurrentOpenAITranscriptionModel() async throws {
        let service = FakeSpeechTranscriptionServing()
        let useCase = TranscribeSpeechUseCase(service: service)

        let text = try await useCase.perform(apiKey: "sk-test", audioData: Data("abc".utf8))

        #expect(text == "привет")
        #expect(service.lastModelID == SpeechTranscriptionModel.currentOpenAIModelID)
        #expect(service.lastFilename == "speech.wav")
    }

    @Test
    @MainActor
    func perform_emptyTranscriptThrows() async {
        let service = FakeSpeechTranscriptionServing()
        service.textToReturn = "   "
        let useCase = TranscribeSpeechUseCase(service: service)

        await #expect(throws: OpenAIServiceError.emptyTranscription) {
            _ = try await useCase.perform(apiKey: "sk-test", audioData: Data("abc".utf8))
        }
    }
}
