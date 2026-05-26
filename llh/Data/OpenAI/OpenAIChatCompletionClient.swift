//
//  OpenAIChatCompletionClient.swift
//  llh
//

import Foundation

/// Text Chat Completions (`POST /v1/chat/completions`) with JSON extracted from assistant content.
struct OpenAIChatCompletionClient: Sendable {
    private let httpClient: OpenAIHTTPClient

    init(httpClient: OpenAIHTTPClient) {
        self.httpClient = httpClient
    }

    func completeText(
        apiKey: String,
        modelID: String,
        temperature: Double,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.invalidResponse
        }

        let requestBody = ChatCompletionsRequest(
            model: modelID,
            temperature: temperature,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ]
        )

        let data = try await httpClient.post(
            path: "/chat/completions",
            apiKey: apiKey,
            body: requestBody
        )
        let decoded = try httpClient.decode(data, as: ChatCompletionsResponse.self)
        return decoded.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func completeJSON<Response: Decodable>(
        apiKey: String,
        modelID: String,
        temperature: Double,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> Response {
        let content = try await completeText(
            apiKey: apiKey,
            modelID: modelID,
            temperature: temperature,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )
        guard !content.isEmpty else {
            throw OpenAIServiceError.invalidStructuredResponse
        }
        let jsonString = Self.extractJSONObjectString(from: content) ?? content
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw OpenAIServiceError.invalidStructuredResponse
        }
        return try JSONDecoder().decode(Response.self, from: jsonData)
    }

    static func extractJSONObjectString(from content: String) -> String? {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}") else { return nil }
        return String(content[start...end])
    }
}

private struct ChatCompletionsRequest: Encodable {
    let model: String
    let temperature: Double
    let messages: [ChatMessage]
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionsResponse: Decodable {
    let choices: [ChatChoice]
}

private struct ChatChoice: Decodable {
    let message: ChatCompletionMessage
}

private struct ChatCompletionMessage: Decodable {
    let content: String
}
