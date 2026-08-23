//
//  TranslationChatServing.swift
//  llh
//

import Foundation

/// Follow-up chat about a translation. Routed through the selected text provider.
protocol TranslationChatServing {
    func completeTranslationChat(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        context: TranslationChatContext,
        messages: [TranslationChatMessage]
    ) async throws -> String
}
