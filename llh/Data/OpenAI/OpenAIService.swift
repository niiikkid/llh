//
//  OpenAIService.swift
//  llh
//

import CoreGraphics
import Foundation

/// Facade implementing `OpenAIServing` by delegating to focused Data/OpenAI services.
struct OpenAIService: OpenAIServing {
    private let modelsService: OpenAIModelsService
    private let ocrService: OpenAIOCRService
    private let translationService: OpenAITranslationService
    private let studyService: OpenAIStudyService

    init(session: URLSession = .shared, requestTimeout: TimeInterval = OpenAIHTTPClient.defaultRequestTimeout) {
        let httpClient = OpenAIHTTPClient(session: session, requestTimeout: requestTimeout)
        self.init(httpClient: httpClient)
    }

    init(
        httpClient: OpenAIHTTPClient,
        ocrService: OpenAIOCRService? = nil,
        translationService: OpenAITranslationService? = nil,
        studyService: OpenAIStudyService? = nil
    ) {
        self.modelsService = OpenAIModelsService(httpClient: httpClient)
        self.ocrService = ocrService ?? OpenAIOCRService(httpClient: httpClient)
        self.translationService = translationService ?? OpenAITranslationService(httpClient: httpClient)
        self.studyService = studyService ?? OpenAIStudyService(httpClient: httpClient)
    }

    func recognizeTextInImage(
        apiKey: String,
        modelID: String,
        image: CGImage
    ) async throws -> String {
        let result = try await ocrService.recognizeTextInImage(
            apiKey: apiKey,
            modelID: modelID,
            image: image
        )
        return result.text
    }

    func fetchModels(apiKey: String) async throws -> [OpenAIModel] {
        try await modelsService.fetchModels(apiKey: apiKey)
    }

    func formatRecognizedText(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        try await translationService.formatRecognizedText(
            apiKey: apiKey,
            modelID: modelID,
            targetLanguage: targetLanguage,
            rawText: rawText
        )
    }

    func buildWordsStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        try await studyService.buildWordsStudyData(
            apiKey: apiKey,
            modelID: modelID,
            targetLanguage: targetLanguage,
            formattedText: formattedText
        )
    }

    func buildGrammarStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> GrammarExplanationPayload {
        try await studyService.buildGrammarStudyData(
            apiKey: apiKey,
            modelID: modelID,
            targetLanguage: targetLanguage,
            formattedText: formattedText
        )
    }
}
