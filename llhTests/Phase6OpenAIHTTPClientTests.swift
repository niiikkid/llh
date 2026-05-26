//
//  Phase6OpenAIHTTPClientTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase6OpenAIHTTPClientTests {
    @Test
    func trimmedToken_rejectsEmptyAndInvalidPrefix() {
        let client = OpenAIHTTPClientTestSupport.makeClient()

        #expect(throws: OpenAIServiceError.invalidTokenFormat) {
            try client.trimmedToken(from: "")
        }
        #expect(throws: OpenAIServiceError.invalidTokenFormat) {
            try client.trimmedToken(from: "not-a-key")
        }
    }

    @Test
    func trimmedToken_acceptsValidKey() throws {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let token = try client.trimmedToken(from: "  sk-test-key  ")
        #expect(token == "sk-test-key")
    }

    @Test
    func get_models_sendsBearerAuthAndDecodesResponse() async throws {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let modelsJSON = """
        {"data":[{"id":"gpt-4o"},{"id":"gpt-4o-mini"}]}
        """

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.absoluteString.hasSuffix("/v1/models") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(modelsJSON.utf8))
        }

        struct ModelsPayload: Decodable {
            struct Item: Decodable { let id: String }
            let data: [Item]
        }

        let data = try await client.get(path: "/models", apiKey: "sk-test")
        let decoded = try client.decode(data, as: ModelsPayload.self)
        #expect(decoded.data.map(\.id) == ["gpt-4o", "gpt-4o-mini"])
    }

    @Test
    func post_chatCompletions_maps401ToUnauthorized() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        struct EmptyBody: Encodable {}

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 401)
            return (response, Data())
        }

        await #expect(throws: OpenAIServiceError.unauthorized) {
            _ = try await client.post(path: "/chat/completions", apiKey: "sk-test", body: EmptyBody())
        }
    }

    @Test
    func post_chatCompletions_maps429ToRateLimited() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        struct EmptyBody: Encodable {}

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 429)
            return (response, Data())
        }

        await #expect(throws: OpenAIServiceError.rateLimited) {
            _ = try await client.post(path: "/chat/completions", apiKey: "sk-test", body: EmptyBody())
        }
    }

    @Test
    func get_models_mapsUnexpectedStatusCode() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 500)
            return (response, Data())
        }

        await #expect(throws: OpenAIServiceError.unexpectedStatusCode(500)) {
            _ = try await client.get(path: "/models", apiKey: "sk-test")
        }
    }

    @Test
    func get_models_mapsHostNotFound() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()

        OpenAIHTTPClientURLProtocolStub.requestHandler = { _ in
            throw URLError(.cannotFindHost)
        }

        await #expect(throws: OpenAIServiceError.hostNotFound) {
            _ = try await client.get(path: "/models", apiKey: "sk-test")
        }
    }

    @Test
    func get_models_mapsNetworkUnavailable() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()

        OpenAIHTTPClientURLProtocolStub.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        await #expect(throws: OpenAIServiceError.networkUnavailable) {
            _ = try await client.get(path: "/models", apiKey: "sk-test")
        }
    }

    @Test
    func get_models_appliesRequestTimeout() async throws {
        let client = OpenAIHTTPClientTestSupport.makeClient(requestTimeout: 45)

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            #expect(request.timeoutInterval == 45)
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data("{}".utf8))
        }

        _ = try await client.get(path: "/models", apiKey: "sk-test")
    }

    @Test
    func get_models_mapsTimedOut() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()

        OpenAIHTTPClientURLProtocolStub.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        await #expect(throws: OpenAIServiceError.timeout) {
            _ = try await client.get(path: "/models", apiKey: "sk-test")
        }
    }

    @Test
    func get_models_mapsCancelled() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()

        OpenAIHTTPClientURLProtocolStub.requestHandler = { _ in
            throw URLError(.cancelled)
        }

        await #expect(throws: OpenAIServiceError.cancelled) {
            _ = try await client.get(path: "/models", apiKey: "sk-test")
        }
    }

    @Test
    func get_models_propagatesTaskCancellation() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()

        OpenAIHTTPClientURLProtocolStub.requestHandler = { _ in
            Thread.sleep(forTimeInterval: 5)
            throw URLError(.unknown)
        }

        let task = Task {
            try await client.get(path: "/models", apiKey: "sk-test")
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }
}
