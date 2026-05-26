//
//  Phase6OpenAITranslationServiceTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase6OpenAITranslationServiceTests {
    @Test
    func formatRecognizedText_postsChatCompletionAndMapsStructuredJSON() async throws {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAITranslationService(httpClient: client)
        let responseJSON = """
        {"choices":[{"message":{"content":"{\\"cleaned_text\\":\\"你好\\",\\"pinyin_text\\":\\"nǐ hǎo\\",\\"russian_translation\\":\\"привет\\"}"}}]}
        """

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(responseJSON.utf8))
        }

        let formatted = try await service.formatRecognizedText(
            apiKey: "sk-test",
            modelID: "gpt-4o",
            targetLanguage: .chinese,
            rawText: "你好"
        )

        #expect(formatted.cleanedText == "你好")
        #expect(formatted.pinyinText == "nǐ hǎo")
        #expect(formatted.russianTranslation == "привет")
    }

    @Test
    func formatRecognizedText_emptyModelIDThrowsInvalidResponse() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAITranslationService(httpClient: client)

        await #expect(throws: OpenAIServiceError.invalidResponse) {
            _ = try await service.formatRecognizedText(
                apiKey: "sk-test",
                modelID: "   ",
                targetLanguage: .english,
                rawText: "hello"
            )
        }
    }

    @Test
    func formatRecognizedText_emptyContentThrowsEmptyFormattedText() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAITranslationService(httpClient: client)
        let responseJSON = """
        {"choices":[{"message":{"content":"   "}}]}
        """

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(responseJSON.utf8))
        }

        await #expect(throws: OpenAIServiceError.emptyFormattedText) {
            _ = try await service.formatRecognizedText(
                apiKey: "sk-test",
                modelID: "gpt-4o",
                targetLanguage: .english,
                rawText: "hello"
            )
        }
    }

    @Test
    func formatRecognizedText_mapsUnauthorizedThroughHTTPClient() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAITranslationService(httpClient: client)

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 401)
            return (response, Data())
        }

        await #expect(throws: OpenAIServiceError.unauthorized) {
            _ = try await service.formatRecognizedText(
                apiKey: "sk-test",
                modelID: "gpt-4o",
                targetLanguage: .english,
                rawText: "hello"
            )
        }
    }
}
