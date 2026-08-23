//
//  OpenAIServing.swift
//  llh
//

import CoreGraphics
import Foundation

/// Text methods are routed by `provider`. `recognizeTextInImage` is OpenAI-only.
protocol OpenAIServing {
    func fetchModels(provider: AIProvider, apiKey: String) async throws -> [OpenAIModel]
    func recognizeTextInImage(
        apiKey: String,
        modelID: String,
        image: CGImage
    ) async throws -> String
    func formatRecognizedText(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText
    func buildWordsStudyData(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload
}
