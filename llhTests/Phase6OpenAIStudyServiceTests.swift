//
//  Phase6OpenAIStudyServiceTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase6OpenAIStudyServiceTests {
    @Test
    func buildWordsStudyData_postsChatCompletionAndMapsEntries() async throws {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAIStudyService(httpClient: client)
        let responseJSON = """
        {"choices":[{"message":{"content":"{\\"entries\\":[{\\"term_pinyin\\":\\"nǐ\\",\\"term_translation\\":\\"ты\\",\\"character_breakdown\\":[]}]}"}}]}
        """

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString.hasSuffix("/v1/chat/completions") == true)
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(responseJSON.utf8))
        }

        let payload = try await service.buildWordsStudyData(
            apiKey: "sk-test",
            modelID: "gpt-4o",
            targetLanguage: .chinese,
            formattedText: StructuredFormattedText(
                cleanedText: "你好",
                pinyinText: "nǐ hǎo",
                russianTranslation: "привет"
            )
        )

        #expect(payload.entries.count == 1)
        #expect(payload.entries[0].termPinyin == "nǐ")
        #expect(payload.entries[0].termTranslation == "ты")
    }

    @Test
    func buildWordsStudyData_emptyEntriesThrowsInvalidStructuredResponse() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAIStudyService(httpClient: client)
        let responseJSON = """
        {"choices":[{"message":{"content":"{\\"entries\\":[]}"}}]}
        """

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(responseJSON.utf8))
        }

        await #expect(throws: OpenAIServiceError.invalidStructuredResponse) {
            _ = try await service.buildWordsStudyData(
                apiKey: "sk-test",
                modelID: "gpt-4o",
                targetLanguage: .chinese,
                formattedText: StructuredFormattedText(
                    cleanedText: "你好",
                    pinyinText: "",
                    russianTranslation: ""
                )
            )
        }
    }

    @Test
    func buildWordsStudyData_mapsUnauthorizedThroughHTTPClient() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAIStudyService(httpClient: client)

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 401)
            return (response, Data())
        }

        await #expect(throws: OpenAIServiceError.unauthorized) {
            _ = try await service.buildWordsStudyData(
                apiKey: "sk-test",
                modelID: "gpt-4o",
                targetLanguage: .english,
                formattedText: StructuredFormattedText(
                    cleanedText: "hello",
                    pinyinText: "",
                    russianTranslation: "привет"
                )
            )
        }
    }
}
