//
//  Phase6ProviderAIServiceTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase6ProviderAIServiceTests {
    @Test
    func formatRecognizedText_routesDeepSeekToDeepSeekHost() async throws {
        let session = OpenAIHTTPClientTestSupport.makeSession()
        let service = OpenAIService(
            openAIHTTPClient: OpenAIHTTPClient(
                session: session,
                baseURL: AIProvider.openAI.apiBaseURL
            ),
            deepSeekHTTPClient: OpenAIHTTPClient(
                session: session,
                baseURL: AIProvider.deepSeek.apiBaseURL
            )
        )
        let formattedJSON = """
        {"cleaned_text":"你好","pinyin_text":"nǐ hǎo","russian_translation":"привет"}
        """
        let responseJSON = """
        {"choices":[{"message":{"content":\(jsonStringLiteral(formattedJSON))}}]}
        """

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
            let body = try OpenAIHTTPClientTestSupport.jsonBody(from: request)
            let thinking = body["thinking"] as? [String: Any]
            #expect(thinking?["type"] as? String == "disabled")
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(responseJSON.utf8))
        }

        let result = try await service.formatRecognizedText(
            provider: .deepSeek,
            apiKey: "sk-test",
            modelID: "deepseek-chat",
            targetLanguage: .chinese,
            rawText: "你好"
        )

        #expect(result.cleanedText == "你好")
        #expect(result.russianTranslation == "привет")
    }

    @Test
    func fetchModels_routesOpenAIToOpenAIHost() async throws {
        let session = OpenAIHTTPClientTestSupport.makeSession()
        let service = OpenAIService(
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
            #expect(request.url?.absoluteString == "https://api.openai.com/v1/models")
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(#"{"data":[{"id":"gpt-4o"}]}"#.utf8))
        }

        let models = try await service.fetchModels(provider: .openAI, apiKey: "sk-test")
        #expect(models.map(\.id) == ["gpt-4o"])
    }

    private func jsonStringLiteral(_ value: String) -> String {
        let data = try! JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8)!
    }
}
