//
//  Phase3FormatCapturedTextUseCaseTests.swift
//  llhTests
//

import CoreGraphics
import Foundation
import Testing
@testable import llh

private final class ConfigurableFakeOpenAIServing: OpenAIServing {
    var formattedResult = StructuredFormattedText(
        cleanedText: "formatted",
        pinyinText: "pin",
        russianTranslation: "перевод"
    )
    var errorToThrow: Error?
    private(set) var formatCallCount = 0

    func fetchModels(apiKey: String) async throws -> [OpenAIModel] { [] }

    func recognizeTextInImage(apiKey: String, modelID: String, image: CGImage) async throws -> String {
        ""
    }

    func formatRecognizedText(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        formatCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return StructuredFormattedText(
            cleanedText: formattedResult.cleanedText,
            pinyinText: formattedResult.pinyinText,
            russianTranslation: formattedResult.russianTranslation
        )
    }

    func buildWordsStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        WordStudyPayload(entries: [])
    }

    func buildPhrasesStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> PhraseStudyPayload {
        PhraseStudyPayload(entries: [])
    }

    func buildGrammarStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> GrammarExplanationPayload {
        GrammarExplanationPayload(structures: [])
    }
}

@MainActor
private func makeRequest(
    rawText: String = "你好",
    forceRetry: Bool = false,
    currentStatus: FormattingStatus = .notRequested,
    currentFormattedText: StructuredFormattedText? = nil
) -> FormatCapturedTextRequest {
    FormatCapturedTextRequest(
        rawText: rawText,
        targetLanguage: .chinese,
        forceRetry: forceRetry,
        currentStatus: currentStatus,
        currentFormattedText: currentFormattedText
    )
}

struct Phase3FormatCapturedTextUseCaseTests {
    @Test
    @MainActor
    func preflight_returnsMissingAPIKey() {
        let useCase = FormatCapturedTextUseCase(openAIService: ConfigurableFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(),
            configuration: FormatCapturedTextConfiguration(apiKey: nil, modelID: "gpt-test")
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
        let useCase = FormatCapturedTextUseCase(openAIService: ConfigurableFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(),
            configuration: FormatCapturedTextConfiguration(apiKey: "sk-test", modelID: nil)
        )

        if case .missingModel = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected missingModel, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func preflight_skipsWhenAlreadySucceeded() {
        let useCase = FormatCapturedTextUseCase(openAIService: ConfigurableFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(
                currentStatus: .succeeded,
                currentFormattedText: StructuredFormattedText(
                    cleanedText: "done",
                    pinyinText: "",
                    russianTranslation: ""
                )
            ),
            configuration: FormatCapturedTextConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )

        if case .skipped = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected skipped, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func preflight_skipsWhenProcessingWithoutForceRetry() {
        let useCase = FormatCapturedTextUseCase(openAIService: ConfigurableFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(currentStatus: .processing),
            configuration: FormatCapturedTextConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )

        if case .skipped = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected skipped, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func preflight_skipsEmptyText() {
        let useCase = FormatCapturedTextUseCase(openAIService: ConfigurableFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(rawText: "   "),
            configuration: FormatCapturedTextConfiguration(apiKey: "sk-test", modelID: "gpt-test")
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
        let useCase = FormatCapturedTextUseCase(openAIService: ConfigurableFakeOpenAIServing())

        let outcome = useCase.preflight(
            request: makeRequest(
                forceRetry: true,
                currentStatus: .succeeded,
                currentFormattedText: StructuredFormattedText(
                    cleanedText: "done",
                    pinyinText: "",
                    russianTranslation: ""
                )
            ),
            configuration: FormatCapturedTextConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )

        if case .ready = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected ready, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func perform_returnsFormattedText() async throws {
        let fake = ConfigurableFakeOpenAIServing()
        let useCase = FormatCapturedTextUseCase(openAIService: fake)
        let request = makeRequest()

        let formatted = try await useCase.perform(
            request: request,
            configuration: FormatCapturedTextConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )

        #expect(formatted.cleanedText == "formatted")
        #expect(fake.formatCallCount == 1)
    }

    @Test
    @MainActor
    func perform_propagatesOpenAIErrors() async {
        var fake = ConfigurableFakeOpenAIServing()
        fake.errorToThrow = OpenAIServiceError.invalidStructuredResponse
        let useCase = FormatCapturedTextUseCase(openAIService: fake)

        do {
            _ = try await useCase.perform(
                request: makeRequest(),
                configuration: FormatCapturedTextConfiguration(apiKey: "sk-test", modelID: "gpt-test")
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
