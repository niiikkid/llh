//
//  Phase3LoadGrammarStudyUseCaseTests.swift
//  llhTests
//

import CoreGraphics
import Foundation
import Testing
@testable import llh

private final class GrammarStudyFakeOpenAIServing: OpenAIServing {
    var grammarResult = GrammarExplanationPayload(
        structures: [
            GrammarStructure(
                title: "Порядок слов",
                explanation: "Подлежащее перед сказуемым.",
                usageNotes: "Типично для утверждений.",
                examples: [
                    GrammarExample(pinyinText: "ni hao", russianTranslation: "привет")
                ]
            )
        ]
    )
    var errorToThrow: Error?
    private(set) var buildGrammarCallCount = 0

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
        StructuredFormattedText(cleanedText: "", pinyinText: "", russianTranslation: "")
    }

    func buildWordsStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        WordStudyPayload(entries: [])
    }

    func buildGrammarStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> GrammarExplanationPayload {
        buildGrammarCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return grammarResult
    }
}

@MainActor
private func makeGrammarRequest(
    profileSupportsWordStudy: Bool = true,
    forceReload: Bool = false,
    formattedText: StructuredFormattedText? = StructuredFormattedText(
        cleanedText: "你好",
        pinyinText: "nǐ hǎo",
        russianTranslation: "привет"
    ),
    grammarStatus: FormattingStatus = .notRequested,
    grammar: GrammarExplanationPayload? = nil
) -> LoadGrammarStudyRequest {
    LoadGrammarStudyRequest(
        targetLanguage: .chinese,
        profileSupportsWordStudy: profileSupportsWordStudy,
        forceReload: forceReload,
        formattedText: formattedText,
        grammarStatus: grammarStatus,
        grammar: grammar
    )
}

struct Phase3LoadGrammarStudyUseCaseTests {
    @Test
    @MainActor
    func preflight_skipsWhenProfileDoesNotSupportWordStudy() {
        let useCase = LoadGrammarStudyUseCase(openAIService: GrammarStudyFakeOpenAIServing())
        let result = useCase.preflight(
            request: makeGrammarRequest(profileSupportsWordStudy: false),
            configuration: LoadGrammarStudyConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )
        #expect(result == .skipped)
    }

    @Test
    @MainActor
    func preflight_missingAPIKey() {
        let useCase = LoadGrammarStudyUseCase(openAIService: GrammarStudyFakeOpenAIServing())
        let result = useCase.preflight(
            request: makeGrammarRequest(),
            configuration: LoadGrammarStudyConfiguration(apiKey: nil, modelID: "gpt-test")
        )
        #expect(result == .missingAPIKey)
    }

    @Test
    @MainActor
    func preflight_skipsWhenGrammarAlreadySucceeded() {
        let useCase = LoadGrammarStudyUseCase(openAIService: GrammarStudyFakeOpenAIServing())
        let result = useCase.preflight(
            request: makeGrammarRequest(
                grammarStatus: .succeeded,
                grammar: GrammarExplanationPayload(
                    structures: [
                        GrammarStructure(
                            title: "t",
                            explanation: "e",
                            usageNotes: "",
                            examples: []
                        )
                    ]
                )
            ),
            configuration: LoadGrammarStudyConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )
        #expect(result == .skipped)
    }

    @Test
    @MainActor
    func perform_returnsGrammarPayload() async throws {
        let fake = GrammarStudyFakeOpenAIServing()
        let useCase = LoadGrammarStudyUseCase(openAIService: fake)
        let payload = try await useCase.perform(
            request: makeGrammarRequest(),
            configuration: LoadGrammarStudyConfiguration(apiKey: "sk-test", modelID: "gpt-test")
        )
        #expect(payload.structures.first?.title == "Порядок слов")
        #expect(fake.buildGrammarCallCount == 1)
    }
}
