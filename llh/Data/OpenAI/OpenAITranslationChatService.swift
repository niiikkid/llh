//
//  OpenAITranslationChatService.swift
//  llh
//

import Foundation

/// Overlay follow-up chat via Chat Completions. Routed by text provider.
struct OpenAITranslationChatService: TranslationChatServing, Sendable {
    private let openAIClient: OpenAIChatCompletionClient
    private let deepSeekClient: OpenAIChatCompletionClient

    init(
        openAIHTTPClient: OpenAIHTTPClient,
        deepSeekHTTPClient: OpenAIHTTPClient,
        requestLogger: (any AITextRequestLogging)? = nil
    ) {
        self.openAIClient = OpenAIChatCompletionClient(
            httpClient: openAIHTTPClient,
            provider: .openAI,
            requestLogger: requestLogger
        )
        self.deepSeekClient = OpenAIChatCompletionClient(
            httpClient: deepSeekHTTPClient,
            provider: .deepSeek,
            requestLogger: requestLogger
        )
    }

    func completeTranslationChat(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        context: TranslationChatContext,
        messages: [TranslationChatMessage]
    ) async throws -> String {
        let turns = [
            ChatCompletionTurn(
                role: "system",
                content: OpenAIPromptBuilder.translationChatSystemPrompt(context: context)
            )
        ]
            + messages.map { message in
                ChatCompletionTurn(role: message.role.rawValue, content: message.text)
            }

        let content = try await client(for: provider).completeConversation(
            apiKey: apiKey,
            modelID: modelID,
            temperature: 0.3,
            messages: turns,
            operation: .translationChat
        )
        guard !content.isEmpty else {
            throw OpenAIServiceError.emptyChatReply
        }
        return content
    }

    private func client(for provider: AIProvider) -> OpenAIChatCompletionClient {
        switch provider {
        case .openAI: openAIClient
        case .deepSeek: deepSeekClient
        }
    }
}
