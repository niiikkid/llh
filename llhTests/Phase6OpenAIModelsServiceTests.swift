//
//  Phase6OpenAIModelsServiceTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase6OpenAIModelsServiceTests {
    @Test
    func fetchModels_sortsByLocalizedStandardCompare() async throws {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAIModelsService(httpClient: client)
        let modelsJSON = """
        {"object":"list","data":[{"id":"gpt-4o-mini","object":"model"},{"id":"gpt-4o","object":"model"}]}
        """

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.absoluteString.hasSuffix("/v1/models") == true)
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(modelsJSON.utf8))
        }

        let models = try await service.fetchModels(apiKey: "sk-test")
        #expect(models.map(\.id) == ["gpt-4o", "gpt-4o-mini"])
    }

    @Test
    func fetchModels_emptyDataThrowsNoModelsFound() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAIModelsService(httpClient: client)
        let modelsJSON = """
        {"object":"list","data":[]}
        """

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(modelsJSON.utf8))
        }

        await #expect(throws: OpenAIServiceError.noModelsFound) {
            _ = try await service.fetchModels(apiKey: "sk-test")
        }
    }

    @Test
    func fetchModels_mapsUnauthorizedThroughHTTPClient() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAIModelsService(httpClient: client)

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 401)
            return (response, Data())
        }

        await #expect(throws: OpenAIServiceError.unauthorized) {
            _ = try await service.fetchModels(apiKey: "sk-test")
        }
    }
}
