//
//  FormatCapturedTextUseCase.swift
//  llh
//

import Foundation

struct FormatCapturedTextRequest: Sendable {
    let rawText: String
    let targetLanguage: LearningLanguage
    let forceRetry: Bool
    let currentStatus: FormattingStatus
    let currentFormattedText: StructuredFormattedText?
}

struct FormatCapturedTextConfiguration: Sendable {
    let apiKey: String?
    let modelID: String?
}

enum FormatCapturedTextPreflight: Sendable {
    case missingAPIKey
    case missingModel
    case skipped
    case ready
}

@MainActor
struct FormatCapturedTextUseCase {
    private let openAIService: OpenAIServing

    init(openAIService: OpenAIServing) {
        self.openAIService = openAIService
    }

    func preflight(
        request: FormatCapturedTextRequest,
        configuration: FormatCapturedTextConfiguration
    ) -> FormatCapturedTextPreflight {
        guard configuration.apiKey != nil else {
            return .missingAPIKey
        }
        guard configuration.modelID != nil else {
            return .missingModel
        }

        if !request.forceRetry,
           request.currentStatus == .succeeded,
           request.currentFormattedText?.hasContent == true {
            return .skipped
        }
        if !request.forceRetry, request.currentStatus == .processing {
            return .skipped
        }

        guard !request.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .skipped
        }

        return .ready
    }

    func perform(
        request: FormatCapturedTextRequest,
        configuration: FormatCapturedTextConfiguration
    ) async throws -> StructuredFormattedText {
        guard let apiKey = configuration.apiKey else {
            throw OpenAIServiceError.invalidTokenFormat
        }
        guard let modelID = configuration.modelID else {
            throw OpenAIServiceError.invalidResponse
        }

        return try await openAIService.formatRecognizedText(
            apiKey: apiKey,
            modelID: modelID,
            targetLanguage: request.targetLanguage,
            rawText: request.rawText
        )
    }
}
