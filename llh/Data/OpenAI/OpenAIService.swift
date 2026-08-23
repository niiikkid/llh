//
//  OpenAIService.swift
//  llh
//

import CoreGraphics
import Foundation

/// Facade implementing `OpenAIServing`. Text calls are routed by provider; OCR stays on OpenAI.
struct OpenAIService: OpenAIServing {
    private let openAIStack: ProviderStack
    private let deepSeekStack: ProviderStack
    private let ocrService: OpenAIOCRService

    init(session: URLSession = .shared, requestTimeout: TimeInterval = OpenAIHTTPClient.defaultRequestTimeout) {
        let openAIClient = OpenAIHTTPClient(
            session: session,
            baseURL: AIProvider.openAI.apiBaseURL,
            requestTimeout: requestTimeout
        )
        let deepSeekClient = OpenAIHTTPClient(
            session: session,
            baseURL: AIProvider.deepSeek.apiBaseURL,
            requestTimeout: requestTimeout
        )
        self.init(openAIHTTPClient: openAIClient, deepSeekHTTPClient: deepSeekClient)
    }

    init(
        httpClient: OpenAIHTTPClient,
        ocrService: OpenAIOCRService? = nil,
        translationService: OpenAITranslationService? = nil,
        studyService: OpenAIStudyService? = nil
    ) {
        let deepSeekClient = OpenAIHTTPClient(baseURL: AIProvider.deepSeek.apiBaseURL)
        self.init(
            openAIHTTPClient: httpClient,
            deepSeekHTTPClient: deepSeekClient,
            ocrService: ocrService,
            openAITranslationService: translationService,
            openAIStudyService: studyService
        )
    }

    init(
        openAIHTTPClient: OpenAIHTTPClient,
        deepSeekHTTPClient: OpenAIHTTPClient,
        ocrService: OpenAIOCRService? = nil,
        openAITranslationService: OpenAITranslationService? = nil,
        openAIStudyService: OpenAIStudyService? = nil
    ) {
        self.openAIStack = ProviderStack(
            provider: .openAI,
            httpClient: openAIHTTPClient,
            translationService: openAITranslationService,
            studyService: openAIStudyService
        )
        self.deepSeekStack = ProviderStack(provider: .deepSeek, httpClient: deepSeekHTTPClient)
        self.ocrService = ocrService ?? OpenAIOCRService(httpClient: openAIHTTPClient)
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

    func fetchModels(provider: AIProvider, apiKey: String) async throws -> [OpenAIModel] {
        try await stack(for: provider).modelsService.fetchModels(apiKey: apiKey)
    }

    func formatRecognizedText(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        try await stack(for: provider).translationService.formatRecognizedText(
            apiKey: apiKey,
            modelID: modelID,
            targetLanguage: targetLanguage,
            rawText: rawText
        )
    }

    func buildWordsStudyData(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        try await stack(for: provider).studyService.buildWordsStudyData(
            apiKey: apiKey,
            modelID: modelID,
            targetLanguage: targetLanguage,
            formattedText: formattedText
        )
    }

    func buildGrammarStudyData(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> GrammarExplanationPayload {
        try await stack(for: provider).studyService.buildGrammarStudyData(
            apiKey: apiKey,
            modelID: modelID,
            targetLanguage: targetLanguage,
            formattedText: formattedText
        )
    }

    private func stack(for provider: AIProvider) -> ProviderStack {
        switch provider {
        case .openAI: openAIStack
        case .deepSeek: deepSeekStack
        }
    }
}

private struct ProviderStack: Sendable {
    let modelsService: OpenAIModelsService
    let translationService: OpenAITranslationService
    let studyService: OpenAIStudyService

    init(
        provider: AIProvider,
        httpClient: OpenAIHTTPClient,
        translationService: OpenAITranslationService? = nil,
        studyService: OpenAIStudyService? = nil
    ) {
        self.modelsService = OpenAIModelsService(httpClient: httpClient)
        self.translationService = translationService ?? OpenAITranslationService(
            httpClient: httpClient,
            provider: provider
        )
        self.studyService = studyService ?? OpenAIStudyService(
            httpClient: httpClient,
            provider: provider
        )
    }
}
