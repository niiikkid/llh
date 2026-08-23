//
//  ManageOpenAISettingsUseCase.swift
//  llh
//

import Foundation

struct OpenAISettingsSnapshot: Sendable {
    let selectedTextProvider: AIProvider
    let cachedModels: [OpenAIModel]
    let selectedModelID: String?
    let selectedOCREngine: OCREngine
    let defaultNewProfileLearningLanguage: LearningLanguage
    let translationOverlayMinimumDuration: Double
    let translationOverlaySecondsPerWord: Double
}

enum ValidateAndSaveAPIKeyPreflight: Sendable {
    case emptyToken
    case ready(trimmedToken: String)
}

enum RefreshModelsPreflight: Sendable {
    case missingAPIKey
    case ready(trimmedToken: String)
}

struct FetchAndPersistModelsResult: Sendable {
    let models: [OpenAIModel]
    let selectedModelID: String?
}

@MainActor
final class ManageOpenAISettingsUseCase {
    private var settingsRepository: any SettingsRepository
    private let apiKeyRepository: APIKeyRepository
    private let openAIService: OpenAIServing

    init(
        settingsRepository: any SettingsRepository,
        apiKeyRepository: APIKeyRepository,
        openAIService: OpenAIServing
    ) {
        self.settingsRepository = settingsRepository
        self.apiKeyRepository = apiKeyRepository
        self.openAIService = openAIService
    }

    func loadSettingsSnapshot() -> OpenAISettingsSnapshot {
        let provider = selectedTextProvider()
        let cachedModels = cachedModels(for: provider)
        let selectedModelID = Self.resolveSelectedModelID(
            models: cachedModels,
            currentSelectedModelID: selectedModelID(for: provider)
        )

        return OpenAISettingsSnapshot(
            selectedTextProvider: provider,
            cachedModels: cachedModels,
            selectedModelID: selectedModelID,
            selectedOCREngine: OCREngine(rawValue: settingsRepository.selectedOCREngineRawValue) ?? .local,
            defaultNewProfileLearningLanguage: LearningLanguage(
                rawValue: settingsRepository.selectedLearningLanguageRawValue
            ) ?? .english,
            translationOverlayMinimumDuration: settingsRepository.translationOverlayMinimumDuration,
            translationOverlaySecondsPerWord: settingsRepository.translationOverlaySecondsPerWord
        )
    }

    func selectedTextProvider() -> AIProvider {
        AIProvider(rawValue: settingsRepository.selectedTextProviderRawValue) ?? .openAI
    }

    func selectedModelID(for provider: AIProvider) -> String? {
        switch provider {
        case .openAI:
            settingsRepository.selectedModelID
        case .deepSeek:
            settingsRepository.selectedDeepSeekModelID
        }
    }

    func cachedModels(for provider: AIProvider) -> [OpenAIModel] {
        switch provider {
        case .openAI:
            settingsRepository.cachedModels
        case .deepSeek:
            settingsRepository.cachedDeepSeekModels
        }
    }

    func hasAPIKey(for provider: AIProvider = .openAI) -> Bool {
        apiKeyRepository.loadAPIKey(for: provider) != nil
    }

    func currentAPIKey(for provider: AIProvider = .openAI) -> String? {
        apiKeyRepository.loadAPIKey(for: provider)
    }

    func preflightValidateAndSaveAPIKey(_ token: String) -> ValidateAndSaveAPIKeyPreflight {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            return .emptyToken
        }
        return .ready(trimmedToken: trimmedToken)
    }

    func performValidateAndSaveAPIKey(
        trimmedToken: String,
        currentSelectedModelID: String?,
        provider: AIProvider = .openAI
    ) async throws -> FetchAndPersistModelsResult {
        try await fetchAndPersistModels(
            provider: provider,
            apiKey: trimmedToken,
            currentSelectedModelID: currentSelectedModelID
        )
    }

    func preflightRefreshModels(for provider: AIProvider = .openAI) -> RefreshModelsPreflight {
        guard let token = apiKeyRepository.loadAPIKey(for: provider)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return .missingAPIKey
        }
        return .ready(trimmedToken: token)
    }

    func performRefreshModels(
        currentSelectedModelID: String?,
        provider: AIProvider = .openAI
    ) async throws -> FetchAndPersistModelsResult {
        guard case let .ready(trimmedToken) = preflightRefreshModels(for: provider) else {
            throw OpenAIServiceError.invalidTokenFormat
        }
        return try await fetchAndPersistModels(
            provider: provider,
            apiKey: trimmedToken,
            currentSelectedModelID: currentSelectedModelID
        )
    }

    func deleteAPIKey(for provider: AIProvider = .openAI) throws {
        try apiKeyRepository.deleteAPIKey(for: provider)
    }

    @discardableResult
    func persistSelectedTextProvider(_ provider: AIProvider) -> AIProvider {
        settingsRepository.selectedTextProviderRawValue = provider.rawValue
        return provider
    }

    @discardableResult
    func persistSelectedModelID(_ id: String?, for provider: AIProvider = .openAI) -> String? {
        switch provider {
        case .openAI:
            settingsRepository.selectedModelID = id
        case .deepSeek:
            settingsRepository.selectedDeepSeekModelID = id
        }
        return id
    }

    @discardableResult
    func persistOCREngine(_ engine: OCREngine) -> OCREngine {
        settingsRepository.selectedOCREngineRawValue = engine.rawValue
        return engine
    }

    @discardableResult
    func persistDefaultNewProfileLearningLanguage(_ language: LearningLanguage) -> LearningLanguage {
        settingsRepository.selectedLearningLanguageRawValue = language.rawValue
        return language
    }

    @discardableResult
    func persistTranslationOverlayMinimumDuration(_ duration: Double) -> Double {
        let clampedDuration = min(max(duration, 1), 15)
        settingsRepository.translationOverlayMinimumDuration = clampedDuration
        return clampedDuration
    }

    @discardableResult
    func persistTranslationOverlaySecondsPerWord(_ value: Double) -> Double {
        let clampedValue = min(max(value, 0.1), 2)
        settingsRepository.translationOverlaySecondsPerWord = clampedValue
        return clampedValue
    }

    static func resolveSelectedModelID(
        models: [OpenAIModel],
        currentSelectedModelID: String?
    ) -> String? {
        if let currentSelectedModelID,
           models.contains(where: { $0.id == currentSelectedModelID }) {
            return currentSelectedModelID
        }
        return models.first?.id
    }

    private func fetchAndPersistModels(
        provider: AIProvider,
        apiKey: String,
        currentSelectedModelID: String?
    ) async throws -> FetchAndPersistModelsResult {
        let models = try await openAIService.fetchModels(provider: provider, apiKey: apiKey)
        try apiKeyRepository.saveAPIKey(apiKey, for: provider)
        persistCachedModels(models, for: provider)

        let selectedModelID = Self.resolveSelectedModelID(
            models: models,
            currentSelectedModelID: currentSelectedModelID
        )
        persistSelectedModelID(selectedModelID, for: provider)

        return FetchAndPersistModelsResult(
            models: models,
            selectedModelID: selectedModelID
        )
    }

    private func persistCachedModels(_ models: [OpenAIModel], for provider: AIProvider) {
        switch provider {
        case .openAI:
            settingsRepository.cachedModels = models
        case .deepSeek:
            settingsRepository.cachedDeepSeekModels = models
        }
    }
}
