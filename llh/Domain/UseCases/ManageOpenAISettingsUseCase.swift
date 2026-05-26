//
//  ManageOpenAISettingsUseCase.swift
//  llh
//

import Foundation

struct OpenAISettingsSnapshot: Sendable {
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
struct ManageOpenAISettingsUseCase {
    private let settingsRepository: SettingsRepository
    private let apiKeyRepository: APIKeyRepository
    private let openAIService: OpenAIServing

    init(
        settingsRepository: SettingsRepository,
        apiKeyRepository: APIKeyRepository,
        openAIService: OpenAIServing
    ) {
        self.settingsRepository = settingsRepository
        self.apiKeyRepository = apiKeyRepository
        self.openAIService = openAIService
    }

    func loadSettingsSnapshot() -> OpenAISettingsSnapshot {
        let cachedModels = settingsRepository.cachedModels
        var selectedModelID = settingsRepository.selectedModelID
        if selectedModelID == nil {
            selectedModelID = cachedModels.first?.id
        }

        return OpenAISettingsSnapshot(
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

    func hasAPIKey() -> Bool {
        apiKeyRepository.loadAPIKey() != nil
    }

    func currentAPIKey() -> String? {
        apiKeyRepository.loadAPIKey()
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
        currentSelectedModelID: String?
    ) async throws -> FetchAndPersistModelsResult {
        try await fetchAndPersistModels(
            apiKey: trimmedToken,
            currentSelectedModelID: currentSelectedModelID
        )
    }

    func preflightRefreshModels() -> RefreshModelsPreflight {
        guard let token = apiKeyRepository.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return .missingAPIKey
        }
        return .ready(trimmedToken: token)
    }

    func performRefreshModels(
        currentSelectedModelID: String?
    ) async throws -> FetchAndPersistModelsResult {
        guard case let .ready(trimmedToken) = preflightRefreshModels() else {
            throw OpenAIServiceError.invalidTokenFormat
        }
        return try await fetchAndPersistModels(
            apiKey: trimmedToken,
            currentSelectedModelID: currentSelectedModelID
        )
    }

    func deleteAPIKey() throws {
        try apiKeyRepository.deleteAPIKey()
    }

    @discardableResult
    func persistSelectedModelID(_ id: String?) -> String? {
        settingsRepository.selectedModelID = id
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
        apiKey: String,
        currentSelectedModelID: String?
    ) async throws -> FetchAndPersistModelsResult {
        let models = try await openAIService.fetchModels(apiKey: apiKey)
        try apiKeyRepository.saveAPIKey(apiKey)
        settingsRepository.cachedModels = models

        let selectedModelID = Self.resolveSelectedModelID(
            models: models,
            currentSelectedModelID: currentSelectedModelID
        )
        settingsRepository.selectedModelID = selectedModelID

        return FetchAndPersistModelsResult(
            models: models,
            selectedModelID: selectedModelID
        )
    }
}
