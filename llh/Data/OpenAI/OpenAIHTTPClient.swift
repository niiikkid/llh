//
//  OpenAIHTTPClient.swift
//  llh
//

import Foundation

/// Low-level HTTP transport for OpenAI REST API (`/v1/*`).
/// Handles auth headers, status codes, network error mapping, timeouts and task cancellation.
struct OpenAIHTTPClient: Sendable {
    enum HTTPMethod: String, Sendable {
        case get = "GET"
        case post = "POST"
    }

    static let defaultRequestTimeout: TimeInterval = 120

    private let session: URLSession
    private let baseURL: URL
    private let requestTimeout: TimeInterval

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        requestTimeout: TimeInterval = OpenAIHTTPClient.defaultRequestTimeout
    ) {
        self.session = session
        self.baseURL = baseURL
        self.requestTimeout = requestTimeout
    }

    func trimmedToken(from apiKey: String) throws -> String {
        let token = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, token.hasPrefix("sk-") else {
            throw OpenAIServiceError.invalidTokenFormat
        }
        return token
    }

    func get(path: String, apiKey: String) async throws -> Data {
        try await perform(path: path, method: .get, apiKey: apiKey, body: nil)
    }

    func post<Body: Encodable>(path: String, apiKey: String, body: Body) async throws -> Data {
        let encodedBody = try JSONEncoder().encode(body)
        return try await perform(path: path, method: .post, apiKey: apiKey, body: encodedBody)
    }

    func decode<Response: Decodable>(_ data: Data, as type: Response.Type = Response.self) throws -> Response {
        try JSONDecoder().decode(Response.self, from: data)
    }

    private func perform(
        path: String,
        method: HTTPMethod,
        apiKey: String,
        body: Data?
    ) async throws -> Data {
        try Task.checkCancellation()

        let token = try trimmedToken(from: apiKey)
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw OpenAIServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = requestTimeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            throw mapURLError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw OpenAIServiceError.unauthorized
        case 429:
            throw OpenAIServiceError.rateLimited
        default:
            throw OpenAIServiceError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }

    private func mapURLError(_ error: URLError) -> Error {
        switch error.code {
        case .cannotFindHost, .dnsLookupFailed:
            return OpenAIServiceError.hostNotFound
        case .notConnectedToInternet, .networkConnectionLost, .internationalRoamingOff:
            return OpenAIServiceError.networkUnavailable
        case .timedOut:
            return OpenAIServiceError.timeout
        case .cancelled:
            return OpenAIServiceError.cancelled
        default:
            return error
        }
    }
}
