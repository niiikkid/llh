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
    static func makeClient(
        baseURL: URL = AIProvider.openAI.apiBaseURL,
        requestTimeout: TimeInterval = OpenAIHTTPClient.defaultRequestTimeout
    ) -> OpenAIHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenAIHTTPClientURLProtocolStub.self]
        return OpenAIHTTPClient(
            session: URLSession(configuration: configuration),
            baseURL: baseURL,
            requestTimeout: requestTimeout
        )
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenAIHTTPClientURLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    static func jsonBody(from request: URLRequest) throws -> [String: Any] {
        guard let data = bodyData(from: request) else {
            throw URLError(.cannotDecodeContentData)
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotDecodeContentData)
        }
        return object
    }

    static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let readCount = stream.read(buffer, maxLength: bufferSize)
            if readCount > 0 {
                data.append(buffer, count: readCount)
            } else {
                break
            }
        }
        return data
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
