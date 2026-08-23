//
//  AskTranslationChatUseCase.swift
//  llh
//

import Foundation

enum AskTranslationChatPreflight: Sendable {
    case missingAPIKey
    case missingModel
    case emptyMessage
    case ready
}

@MainActor
struct AskTranslationChatUseCase {
    private let service: TranslationChatServing

    init(service: TranslationChatServing) {
        self.service = service
    }

    func preflight(apiKey: String?, modelID: String?, userText: String) -> AskTranslationChatPreflight {
        guard apiKey != nil else {
            return .missingAPIKey
        }
        guard let modelID, !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .missingModel
        }
        guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .emptyMessage
        }
        return .ready
    }

    func perform(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        context: TranslationChatContext,
        history: [TranslationChatMessage],
        userText: String
    ) async throws -> String {
        switch preflight(apiKey: apiKey, modelID: modelID, userText: userText) {
        case .missingAPIKey:
            throw OpenAIServiceError.invalidTokenFormat
        case .missingModel:
            throw OpenAIServiceError.invalidResponse
        case .emptyMessage:
            throw OpenAIServiceError.emptyChatMessage
        case .ready:
            break
        }

        let trimmedUserText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let messages = history + [TranslationChatMessage(role: .user, text: trimmedUserText)]
        let reply = try await service.completeTranslationChat(
            provider: provider,
            apiKey: apiKey,
            modelID: modelID,
            context: context,
            messages: messages
        )
        let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReply.isEmpty else {
            throw OpenAIServiceError.emptyChatReply
        }
        return trimmedReply
    }
}
