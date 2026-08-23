//
//  OpenAITranslationService.swift
//  llh
//

import Foundation

/// Formats recognized text via Chat Completions (`POST /v1/chat/completions`).
struct OpenAITranslationService: Sendable {
    private let chatClient: OpenAIChatCompletionClient

    init(
        httpClient: OpenAIHTTPClient,
        provider: AIProvider = .openAI,
        requestLogger: (any AITextRequestLogging)? = nil
    ) {
        self.chatClient = OpenAIChatCompletionClient(
            httpClient: httpClient,
            provider: provider,
            requestLogger: requestLogger
        )
    }

    func formatRecognizedText(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        let content = try await chatClient.completeText(
            apiKey: apiKey,
            modelID: modelID,
            temperature: 0,
            systemPrompt: OpenAIPromptBuilder.formatRecognizedTextSystemPrompt(),
            userPrompt: OpenAIPromptBuilder.formatRecognizedTextUserPrompt(
                targetLanguage: targetLanguage,
                rawText: rawText
            ),
            operation: .formatRecognizedText
        )
        guard !content.isEmpty else {
            throw OpenAIServiceError.emptyFormattedText
        }

        let jsonString = OpenAIChatCompletionClient.extractJSONObjectString(from: content) ?? content
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw OpenAIServiceError.invalidStructuredResponse
        }
        let structured = try JSONDecoder().decode(FormattedTextResponseDTO.self, from: jsonData)
        let result = StructuredFormattedText(
            cleanedText: structured.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines),
            pinyinText: structured.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines),
            russianTranslation: structured.russianTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard result.hasContent else {
            throw OpenAIServiceError.emptyFormattedText
        }
        return result
    }
}

private struct FormattedTextResponseDTO: Decodable {
    let cleanedText: String
    let pinyinText: String
    let russianTranslation: String

    enum CodingKeys: String, CodingKey {
        case cleanedText = "cleaned_text"
        case pinyinText = "pinyin_text"
        case russianTranslation = "russian_translation"
    }
}
