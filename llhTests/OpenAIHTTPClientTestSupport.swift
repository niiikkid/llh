//
//  OpenAIHTTPClientTestSupport.swift
//  llhTests
//

import Foundation
@testable import llh

final class OpenAIHTTPClientURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

enum OpenAIHTTPClientTestSupport {
    static func makeClient() -> OpenAIHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenAIHTTPClientURLProtocolStub.self]
        return OpenAIHTTPClient(session: URLSession(configuration: configuration))
    }

    static func httpResponse(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
