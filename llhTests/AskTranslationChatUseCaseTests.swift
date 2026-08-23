//
//  AskTranslationChatUseCaseTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

private final class FakeTranslationChatServing: TranslationChatServing {
    var reply = "Это вежливое приветствие."
    var errorToThrow: Error?
    private(set) var lastProvider: AIProvider?
    private(set) var lastContext: TranslationChatContext?
    private(set) var lastMessages: [TranslationChatMessage] = []

    func completeTranslationChat(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        context: TranslationChatContext,
        messages: [TranslationChatMessage]
    ) async throws -> String {
        lastProvider = provider
        lastContext = context
        lastMessages = messages
        if let errorToThrow {
            throw errorToThrow
        }
        return reply
    }
}

struct AskTranslationChatUseCaseTests {
    private var context: TranslationChatContext {
        TranslationChatContext(
            formattedText: StructuredFormattedText(
                cleanedText: "你好",
                pinyinText: "nǐ hǎo",
                russianTranslation: "привет"
            ),
            words: WordStudyPayload(entries: [
                WordStudyEntry(termPinyin: "nǐ", termTranslation: "ты", characterBreakdown: [])
            ])
        )
    }

    @Test
    @MainActor
    func preflight_requiresKeyModelAndText() {
        let useCase = AskTranslationChatUseCase(service: FakeTranslationChatServing())

        #expect(useCase.preflight(apiKey: nil, modelID: "gpt", userText: "что это?") == .missingAPIKey)
        #expect(useCase.preflight(apiKey: "sk-test", modelID: "  ", userText: "что это?") == .missingModel)
        #expect(useCase.preflight(apiKey: "sk-test", modelID: "gpt", userText: "   ") == .emptyMessage)
        #expect(useCase.preflight(apiKey: "sk-test", modelID: "gpt", userText: "что это?") == .ready)
    }

    @Test
    @MainActor
    func perform_routesProviderAndIncludesTranslationContext() async throws {
        let service = FakeTranslationChatServing()
        let useCase = AskTranslationChatUseCase(service: service)

        let reply = try await useCase.perform(
            provider: .deepSeek,
            apiKey: "sk-test",
            modelID: "deepseek-chat",
            context: context,
            history: [TranslationChatMessage(role: .user, text: "раньше")],
            userText: "почему nǐ?"
        )

        #expect(reply == "Это вежливое приветствие.")
        #expect(service.lastProvider == .deepSeek)
        #expect(service.lastContext?.pinyinText == "nǐ hǎo")
        #expect(service.lastContext?.russianTranslation == "привет")
        #expect(service.lastContext?.wordEntries.first?.termPinyin == "nǐ")
        #expect(service.lastMessages.map(\.text) == ["раньше", "почему nǐ?"])
    }

    @Test
    @MainActor
    func perform_emptyReplyThrows() async {
        let service = FakeTranslationChatServing()
        service.reply = "  "
        let useCase = AskTranslationChatUseCase(service: service)

        await #expect(throws: OpenAIServiceError.emptyChatReply) {
            _ = try await useCase.perform(
                provider: .openAI,
                apiKey: "sk-test",
                modelID: "gpt-4o",
                context: context,
                history: [],
                userText: "что это?"
            )
        }
    }
}
