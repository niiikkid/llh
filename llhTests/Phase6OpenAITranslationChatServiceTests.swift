//
//  Phase6OpenAITranslationChatServiceTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase6OpenAITranslationChatServiceTests {
    @Test
    func completeTranslationChat_routesDeepSeekAndDisablesThinking() async throws {
        let session = OpenAIHTTPClientTestSupport.makeSession()
        let service = OpenAITranslationChatService(
            openAIHTTPClient: OpenAIHTTPClient(
                session: session,
                baseURL: AIProvider.openAI.apiBaseURL
            ),
            deepSeekHTTPClient: OpenAIHTTPClient(
                session: session,
                baseURL: AIProvider.deepSeek.apiBaseURL
            )
        )

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
            let body = try OpenAIHTTPClientTestSupport.jsonBody(from: request)
            let thinking = body["thinking"] as? [String: Any]
            #expect(thinking?["type"] as? String == "disabled")
            let messages = body["messages"] as? [[String: Any]]
            #expect(messages?.first?["role"] as? String == "system")
            #expect((messages?.first?["content"] as? String)?.contains("nǐ hǎo") == true)
            #expect(messages?.last?["content"] as? String == "что значит nǐ?")
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(#"{"choices":[{"message":{"content":"это местоимение ты"}}]}"#.utf8))
        }

        let reply = try await service.completeTranslationChat(
            provider: .deepSeek,
            apiKey: "sk-test",
            modelID: "deepseek-chat",
            context: TranslationChatContext(
                formattedText: StructuredFormattedText(
                    cleanedText: "你好",
                    pinyinText: "nǐ hǎo",
                    russianTranslation: "привет"
                )
            ),
            messages: [TranslationChatMessage(role: .user, text: "что значит nǐ?")]
        )

        #expect(reply == "это местоимение ты")
    }

    @Test
    func completeTranslationChat_routesOpenAIWithoutThinking() async throws {
        let session = OpenAIHTTPClientTestSupport.makeSession()
        let service = OpenAITranslationChatService(
            openAIHTTPClient: OpenAIHTTPClient(
                session: session,
                baseURL: AIProvider.openAI.apiBaseURL
            ),
            deepSeekHTTPClient: OpenAIHTTPClient(
                session: session,
                baseURL: AIProvider.deepSeek.apiBaseURL
            )
        )

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
            let body = try OpenAIHTTPClientTestSupport.jsonBody(from: request)
            #expect(body["thinking"] == nil)
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(#"{"choices":[{"message":{"content":"ответ"}}]}"#.utf8))
        }

        let reply = try await service.completeTranslationChat(
            provider: .openAI,
            apiKey: "sk-test",
            modelID: "gpt-4o",
            context: TranslationChatContext(
                formattedText: StructuredFormattedText(
                    cleanedText: "hello",
                    pinyinText: "",
                    russianTranslation: "привет"
                )
            ),
            messages: [TranslationChatMessage(role: .user, text: "привет")]
        )

        #expect(reply == "ответ")
    }
}
