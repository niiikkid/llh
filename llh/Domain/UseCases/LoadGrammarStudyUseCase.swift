//
//  LoadGrammarStudyUseCase.swift
//  llh
//

import Foundation

struct LoadGrammarStudyRequest: Sendable {
    let targetLanguage: LearningLanguage
    let profileSupportsWordStudy: Bool
    let forceReload: Bool
    let formattedText: StructuredFormattedText?
    let grammarStatus: FormattingStatus
    let grammar: GrammarExplanationPayload?
}

struct LoadGrammarStudyConfiguration: Sendable {
    let provider: AIProvider
    let apiKey: String?
    let modelID: String?

    init(provider: AIProvider = .openAI, apiKey: String?, modelID: String?) {
        self.provider = provider
        self.apiKey = apiKey
        self.modelID = modelID
    }
}

enum LoadGrammarStudyPreflight: Sendable {
    case missingAPIKey
    case missingModel
    case skipped
    case ready
}

@MainActor
struct LoadGrammarStudyUseCase {
    private let openAIService: OpenAIServing

    init(openAIService: OpenAIServing) {
        self.openAIService = openAIService
    }

    func preflight(
        request: LoadGrammarStudyRequest,
        configuration: LoadGrammarStudyConfiguration
    ) -> LoadGrammarStudyPreflight {
        guard request.profileSupportsWordStudy else {
            return .skipped
        }
        guard configuration.apiKey != nil else {
            return .missingAPIKey
        }
        guard configuration.modelID != nil else {
            return .missingModel
        }
        guard let formattedText = request.formattedText, formattedText.hasContent else {
            return .skipped
        }
        if !request.forceReload,
           request.grammarStatus == .succeeded,
           request.grammar?.hasContent == true {
            return .skipped
        }
        if !request.forceReload, request.grammarStatus == .processing {
            return .skipped
        }
        return .ready
    }

    func perform(
        request: LoadGrammarStudyRequest,
        configuration: LoadGrammarStudyConfiguration
    ) async throws -> GrammarExplanationPayload {
        guard let apiKey = configuration.apiKey else {
            throw OpenAIServiceError.invalidTokenFormat
        }
        guard let modelID = configuration.modelID else {
            throw OpenAIServiceError.invalidResponse
        }
        guard let formattedText = request.formattedText, formattedText.hasContent else {
            throw OpenAIServiceError.invalidResponse
        }

        return try await openAIService.buildGrammarStudyData(
            provider: configuration.provider,
            apiKey: apiKey,
            modelID: modelID,
            targetLanguage: request.targetLanguage,
            formattedText: formattedText
        )
    }
}
