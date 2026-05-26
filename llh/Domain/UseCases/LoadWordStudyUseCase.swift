//
//  LoadWordStudyUseCase.swift
//  llh
//

import Foundation

struct LoadWordStudyRequest: Sendable {
    let targetLanguage: LearningLanguage
    let profileSupportsWordStudy: Bool
    let forceReload: Bool
    let formattedText: StructuredFormattedText?
    let wordsStatus: FormattingStatus
    let words: WordStudyPayload?
}

struct LoadWordStudyConfiguration: Sendable {
    let apiKey: String?
    let modelID: String?
}

enum LoadWordStudyPreflight: Sendable {
    case missingAPIKey
    case missingModel
    case skipped
    case ready
}

@MainActor
struct LoadWordStudyUseCase {
    private let openAIService: OpenAIServing

    init(openAIService: OpenAIServing) {
        self.openAIService = openAIService
    }

    func preflight(
        request: LoadWordStudyRequest,
        configuration: LoadWordStudyConfiguration
    ) -> LoadWordStudyPreflight {
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
           request.wordsStatus == .succeeded,
           request.words?.hasContent == true {
            return .skipped
        }
        if !request.forceReload, request.wordsStatus == .processing {
            return .skipped
        }
        return .ready
    }

    func perform(
        request: LoadWordStudyRequest,
        configuration: LoadWordStudyConfiguration
    ) async throws -> WordStudyPayload {
        guard let apiKey = configuration.apiKey else {
            throw OpenAIServiceError.invalidTokenFormat
        }
        guard let modelID = configuration.modelID else {
            throw OpenAIServiceError.invalidResponse
        }
        guard let formattedText = request.formattedText, formattedText.hasContent else {
            throw OpenAIServiceError.invalidResponse
        }

        return try await openAIService.buildWordsStudyData(
            apiKey: apiKey,
            modelID: modelID,
            targetLanguage: request.targetLanguage,
            formattedText: formattedText
        )
    }
}
