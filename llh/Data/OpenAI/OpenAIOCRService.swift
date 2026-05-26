//
//  OpenAIOCRService.swift
//  llh
//

import CoreGraphics
import Foundation

/// AI OCR via OpenAI Chat Completions vision (`POST /v1/chat/completions`).
struct OpenAIOCRService: OpenAIOCRServing, Sendable {
    private let httpClient: OpenAIHTTPClient

    init(httpClient: OpenAIHTTPClient) {
        self.httpClient = httpClient
    }

    func recognizeTextInImage(
        apiKey: String,
        modelID: String,
        image: CGImage
    ) async throws -> OCRResult {
        try Task.checkCancellation()

        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.invalidResponse
        }

        let imageData = try await OCRImagePreprocessor.jpegData(from: image)
        try Task.checkCancellation()

        let imageBase64 = imageData.base64EncodedString()
        let requestBody = VisionChatCompletionsRequest(
            model: modelID,
            temperature: 0,
            messages: [
                VisionChatMessage(
                    role: "user",
                    content: [
                        .init(type: "text", text: OpenAIPromptBuilder.recognizeTextInImageUserPrompt()),
                        .init(type: "image_url", imageURL: .init(url: "data:image/jpeg;base64,\(imageBase64)"))
                    ]
                )
            ]
        )

        let data = try await httpClient.post(
            path: "/chat/completions",
            apiKey: apiKey,
            body: requestBody
        )
        try Task.checkCancellation()

        let decoded = try httpClient.decode(data, as: VisionChatCompletionsResponse.self)
        let recognizedText = decoded.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !recognizedText.isEmpty else {
            throw OpenAIServiceError.emptyRecognizedText
        }
        let lines = recognizedText.components(separatedBy: .newlines)
        let text = TextFormatter.normalizeRecognizedLines(lines)
        return OCRResult(text: text, lines: lines)
    }
}

private struct VisionChatCompletionsRequest: Encodable {
    let model: String
    let temperature: Double
    let messages: [VisionChatMessage]
}

private struct VisionChatMessage: Encodable {
    let role: String
    let content: [VisionChatContent]
}

private struct VisionChatContent: Encodable {
    let type: String
    let text: String?
    let imageURL: VisionImageURL?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    init(type: String, text: String? = nil, imageURL: VisionImageURL? = nil) {
        self.type = type
        self.text = text
        self.imageURL = imageURL
    }
}

private struct VisionImageURL: Encodable {
    let url: String
}

private struct VisionChatCompletionsResponse: Decodable {
    let choices: [VisionChatChoice]
}

private struct VisionChatChoice: Decodable {
    let message: VisionChatCompletionMessage
}

private struct VisionChatCompletionMessage: Decodable {
    let content: String
}
