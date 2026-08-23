//
//  OpenAIChatCompletionClient.swift
//  llh
//

import Foundation

/// Text Chat Completions (`POST /chat/completions`) with JSON extracted from assistant content.
struct OpenAIChatCompletionClient: Sendable {
    private let httpClient: OpenAIHTTPClient
    private let provider: AIProvider
    private let requestLogger: (any AITextRequestLogging)?

    init(
        httpClient: OpenAIHTTPClient,
        provider: AIProvider = .openAI,
        requestLogger: (any AITextRequestLogging)? = nil
    ) {
        self.httpClient = httpClient
        self.provider = provider
        self.requestLogger = requestLogger
    }

    func completeText(
        apiKey: String,
        modelID: String,
        temperature: Double,
        systemPrompt: String,
        userPrompt: String,
        operation: AITextRequestOperation
    ) async throws -> String {
        try await completeConversation(
            apiKey: apiKey,
            modelID: modelID,
            temperature: temperature,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            operation: operation
        )
    }

    func completeConversation(
        apiKey: String,
        modelID: String,
        temperature: Double,
        messages: [ChatCompletionTurn],
        operation: AITextRequestOperation
    ) async throws -> String {
        let startedAt = Date()
        do {
            guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw OpenAIServiceError.invalidResponse
            }
            guard !messages.isEmpty else {
                throw OpenAIServiceError.invalidResponse
            }

            let requestBody = ChatCompletionsRequest(
                model: modelID,
                temperature: temperature,
                messages: messages.map { ChatMessage(role: $0.role, content: $0.content) },
                thinking: thinkingConfig
            )

            let data = try await httpClient.post(
                path: "/chat/completions",
                apiKey: apiKey,
                body: requestBody
            )
            let decoded = try httpClient.decode(data, as: ChatCompletionsResponse.self)
            let content = decoded.choices.first?.message.content?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            record(
                operation: operation,
                modelID: modelID,
                messages: messages,
                responseText: content,
                errorDescription: nil,
                startedAt: startedAt
            )
            return content
        } catch {
            record(
                operation: operation,
                modelID: modelID,
                messages: messages,
                responseText: nil,
                errorDescription: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
                startedAt: startedAt
            )
            throw error
        }
    }

    func completeJSON<Response: Decodable>(
        apiKey: String,
        modelID: String,
        temperature: Double,
        systemPrompt: String,
        userPrompt: String,
        operation: AITextRequestOperation
    ) async throws -> Response {
        let content = try await completeText(
            apiKey: apiKey,
            modelID: modelID,
            temperature: temperature,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            operation: operation
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

    private func record(
        operation: AITextRequestOperation,
        modelID: String,
        messages: [ChatCompletionTurn],
        responseText: String?,
        errorDescription: String?,
        startedAt: Date
    ) {
        requestLogger?.record(
            AITextRequestLogEntry(
                operation: operation,
                provider: provider,
                modelID: modelID,
                messages: messages.map { AITextRequestLogMessage(role: $0.role, content: $0.content) },
                responseText: responseText,
                errorDescription: errorDescription,
                duration: Date().timeIntervalSince(startedAt)
            )
        )
    }

    /// DeepSeek V4 enables thinking by default (high effort on Pro). That makes a non-stream
    /// translation look hung. OpenAI rejects unknown `thinking`, so it is omitted there.
    private var thinkingConfig: ThinkingConfig? {
        switch provider {
        case .openAI:
            nil
        case .deepSeek:
            ThinkingConfig(type: "disabled")
        }
    }
}

struct ChatCompletionTurn: Equatable, Sendable {
    let role: String
    let content: String
}

private struct ChatCompletionsRequest: Encodable {
    let model: String
    let temperature: Double
    let messages: [ChatMessage]
    let thinking: ThinkingConfig?

    enum CodingKeys: String, CodingKey {
        case model
        case temperature
        case messages
        case thinking
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(thinking, forKey: .thinking)
    }
}

private struct ThinkingConfig: Encodable {
    let type: String
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
    let content: String?
}
