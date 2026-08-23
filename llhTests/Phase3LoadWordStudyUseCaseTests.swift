//
//  Phase3LoadWordStudyUseCaseTests.swift
//  llhTests
//

import CoreGraphics
import Foundation
import Testing
@testable import llh

private final class WordStudyFakeOpenAIServing: OpenAIServing {
    var wordsResult = WordStudyPayload(
        entries: [
            WordStudyEntry(
                termPinyin: "ni",
                termTranslation: "ты",
                characterBreakdown: []
            )
        ]
    )
    var errorToThrow: Error?
    private(set) var buildWordsCallCount = 0

    func fetchModels(provider: AIProvider, apiKey: String) async throws -> [OpenAIModel] { [] }

    func recognizeTextInImage(apiKey: String, modelID: String, image: CGImage) async throws -> String {
        ""
    }

    func formatRecognizedText(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        StructuredFormattedText(cleanedText: "", pinyinText: "", russianTranslation: "")
    }

    func buildWordsStudyData(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        buildWordsCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return wordsResult
    }
}

@MainActor
private func makeRequest(
    profileSupportsWordStudy: Bool = true,
    forceReload: Bool = false,
    formattedText: StructuredFormattedText? = StructuredFormattedText(
        cleanedText: "你好",
        pinyinText: "nǐ hǎo",
        russianTranslation: "привет"
    ),
    wordsStatus: FormattingStatus = .notRequested,
    words: WordStudyPayload? = nil
) -> LoadWordStudyRequest {
    LoadWordStudyRequest(
        targetLanguage: .chinese,
        profileSupportsWordStudy: profileSupportsWordStudy,
        forceReload: forceReload,
        formattedText: formattedText,
        wordsStatus: wordsStatus,
        words: words
    )
}

struct Phase3LoadWordStudyUseCaseTests {
    @Test
    @MainActor
    func preflight_skipsWhenProfileDoesNotSupportWordStudy() {
        let useCase = LoadWordStudyUseCase(openAIService: WordStudyFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(profileSupportsWordStudy: false),
            configuration: LoadWordStudyConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )

        if case .skipped = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected skipped, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func preflight_returnsMissingAPIKey() {
        let useCase = LoadWordStudyUseCase(openAIService: WordStudyFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(),
            configuration: LoadWordStudyConfiguration(apiKey: nil, modelID: "gpt-test")
        )

        if case .missingAPIKey = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected missingAPIKey, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func preflight_returnsMissingModel() {
        let useCase = LoadWordStudyUseCase(openAIService: WordStudyFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(),
            configuration: LoadWordStudyConfiguration(apiKey: "sk-test", modelID: nil)
        )

        if case .missingModel = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected missingModel, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func preflight_skipsWithoutFormattedText() {
        let useCase = LoadWordStudyUseCase(openAIService: WordStudyFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(formattedText: nil),
            configuration: LoadWordStudyConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )

        if case .skipped = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected skipped, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func preflight_skipsWhenAlreadySucceeded() {
        let useCase = LoadWordStudyUseCase(openAIService: WordStudyFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(
                wordsStatus: .succeeded,
                words: WordStudyPayload(entries: [WordStudyEntry(termPinyin: "a", termTranslation: "b", characterBreakdown: [])])
            ),
            configuration: LoadWordStudyConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )

        if case .skipped = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected skipped, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func preflight_skipsWhenProcessingWithoutForceReload() {
        let useCase = LoadWordStudyUseCase(openAIService: WordStudyFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(wordsStatus: .processing),
            configuration: LoadWordStudyConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )

        if case .skipped = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected skipped, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func preflight_allowsRetryWhenAlreadySucceeded() {
        let useCase = LoadWordStudyUseCase(openAIService: WordStudyFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(
                forceReload: true,
                wordsStatus: .succeeded,
                words: WordStudyPayload(entries: [WordStudyEntry(termPinyin: "a", termTranslation: "b", characterBreakdown: [])])
            ),
            configuration: LoadWordStudyConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )

        if case .ready = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected ready, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func perform_returnsWordStudyPayload() async throws {
        let fake = WordStudyFakeOpenAIServing()
        let useCase = LoadWordStudyUseCase(openAIService: fake)
        let request = makeRequest()

        let payload = try await useCase.perform(
            request: request,
            configuration: LoadWordStudyConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )

        #expect(payload.entries.count == 1)
        #expect(payload.entries[0].termTranslation == "ты")
        #expect(fake.buildWordsCallCount == 1)
    }

    @Test
    @MainActor
    func perform_propagatesOpenAIErrors() async {
        let fake = WordStudyFakeOpenAIServing()
        fake.errorToThrow = OpenAIServiceError.invalidStructuredResponse
        let useCase = LoadWordStudyUseCase(openAIService: fake)

        do {
            _ = try await useCase.perform(
                request: makeRequest(),
                configuration: LoadWordStudyConfiguration(apiKey: "sk-test", modelID: "gpt-test")
            )
            Issue.record("Expected OpenAIServiceError.invalidStructuredResponse")
        } catch let error as OpenAIServiceError {
            if case .invalidStructuredResponse = error {
                #expect(Bool(true))
            } else {
                Issue.record("Unexpected OpenAIServiceError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
