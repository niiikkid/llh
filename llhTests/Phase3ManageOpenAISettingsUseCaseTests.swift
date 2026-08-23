//
//  Phase3ManageOpenAISettingsUseCaseTests.swift
//  llhTests
//

import CoreGraphics
import Foundation
import Testing
@testable import llh

private final class InMemorySettingsRepository: SettingsRepository {
    var selectedTextProviderRawValue = AIProvider.openAI.rawValue
    var selectedModelID: String?
    var selectedLearningLanguageRawValue = LearningLanguage.english.rawValue
    var cachedModels: [OpenAIModel] = []
    var selectedDeepSeekModelID: String?
    var cachedDeepSeekModels: [OpenAIModel] = []
    var selectedOCREngineRawValue = OCREngine.local.rawValue
    var translationOverlayMinimumDuration = 3.0
    var translationOverlaySecondsPerWord = 0.33
}

private final class InMemoryAPIKeyRepository: APIKeyRepository {
    private var keys: [AIProvider: String] = [:]

    func loadAPIKey(for provider: AIProvider) -> String? {
        keys[provider]
    }

    func saveAPIKey(_ key: String, for provider: AIProvider) throws {
        keys[provider] = key
    }

    func deleteAPIKey(for provider: AIProvider) throws {
        keys[provider] = nil
    }
}

private final class SettingsFakeOpenAIServing: OpenAIServing {
    var modelsToReturn: [OpenAIModel] = [
        OpenAIModel(id: "gpt-4o"),
        OpenAIModel(id: "gpt-4o-mini")
    ]
    var modelsByProvider: [AIProvider: [OpenAIModel]] = [:]
    var errorToThrow: Error?
    private(set) var fetchModelsCallCount = 0
    private(set) var lastFetchedAPIKey: String?
    private(set) var lastFetchedProvider: AIProvider?

    func fetchModels(provider: AIProvider, apiKey: String) async throws -> [OpenAIModel] {
        fetchModelsCallCount += 1
        lastFetchedAPIKey = apiKey
        lastFetchedProvider = provider
        if let errorToThrow {
            throw errorToThrow
        }
        return modelsByProvider[provider] ?? modelsToReturn
    }

    func recognizeTextInImage(apiKey: String, modelID: String, image: CGImage) async throws -> String {
        ""
    }

    func formatRecognizedText(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        StructuredFormattedText(cleanedText: "", pinyinText: "", russianTranslation: "")
    }

    func buildWordsStudyData(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        WordStudyPayload(entries: [])
    }

    func buildGrammarStudyData(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> GrammarExplanationPayload {
        GrammarExplanationPayload(structures: [])
    }
}

@MainActor
private func makeUseCase(
    settings: InMemorySettingsRepository = InMemorySettingsRepository(),
    apiKeys: InMemoryAPIKeyRepository = InMemoryAPIKeyRepository(),
    openAI: SettingsFakeOpenAIServing = SettingsFakeOpenAIServing()
) -> (ManageOpenAISettingsUseCase, InMemorySettingsRepository, InMemoryAPIKeyRepository, SettingsFakeOpenAIServing) {
    let useCase = ManageOpenAISettingsUseCase(
        settingsRepository: settings,
        apiKeyRepository: apiKeys,
        openAIService: openAI
    )
    return (useCase, settings, apiKeys, openAI)
}

@MainActor
struct Phase3ManageOpenAISettingsUseCaseTests {
    @Test
    func loadSettingsSnapshot_fallsBackToFirstCachedModelWhenSelectionMissing() {
        let settings = InMemorySettingsRepository()
        settings.cachedModels = [OpenAIModel(id: "gpt-4o")]
        let (useCase, _, _, _) = makeUseCase(settings: settings)

        let snapshot = useCase.loadSettingsSnapshot()

        #expect(snapshot.selectedModelID == "gpt-4o")
        #expect(snapshot.selectedOCREngine == .local)
        #expect(snapshot.defaultNewProfileLearningLanguage == .english)
    }

    @Test
    func loadSettingsSnapshot_fallsBackWhenStoredSelectionNotInCache() {
        let settings = InMemorySettingsRepository()
        settings.cachedModels = [OpenAIModel(id: "gpt-4o")]
        settings.selectedModelID = "gpt-4o-mini"
        let (useCase, _, _, _) = makeUseCase(settings: settings)

        let snapshot = useCase.loadSettingsSnapshot()

        #expect(snapshot.selectedModelID == "gpt-4o")
    }

    @Test
    func hasAPIKey_andCurrentAPIKey_reflectRepositoryState() throws {
        let apiKeys = InMemoryAPIKeyRepository()
        let (useCase, _, _, _) = makeUseCase(apiKeys: apiKeys)

        #expect(useCase.hasAPIKey() == false)
        #expect(useCase.currentAPIKey() == nil)

        try apiKeys.saveAPIKey("sk-test")

        #expect(useCase.hasAPIKey() == true)
        #expect(useCase.currentAPIKey() == "sk-test")
    }

    @Test
    func preflightValidateAndSaveAPIKey_emptyToken() {
        let (useCase, _, _, _) = makeUseCase()

        if case .emptyToken = useCase.preflightValidateAndSaveAPIKey("   ") {
            #expect(Bool(true))
        } else {
            Issue.record("Expected emptyToken preflight")
        }
    }

    @Test
    func preflightValidateAndSaveAPIKey_ready() {
        let (useCase, _, _, _) = makeUseCase()

        if case .ready(let trimmed) = useCase.preflightValidateAndSaveAPIKey("  sk-test  ") {
            #expect(trimmed == "sk-test")
        } else {
            Issue.record("Expected ready preflight")
        }
    }

    @Test
    func performValidateAndSaveAPIKey_persistsModelsAndKeepsValidSelection() async throws {
        let settingsRepo = InMemorySettingsRepository()
        let apiKeysRepo = InMemoryAPIKeyRepository()
        let openAIService = SettingsFakeOpenAIServing()
        let (useCase, _, _, _) = makeUseCase(
            settings: settingsRepo,
            apiKeys: apiKeysRepo,
            openAI: openAIService
        )

        let result = try await useCase.performValidateAndSaveAPIKey(
            trimmedToken: "sk-test",
            currentSelectedModelID: "gpt-4o-mini"
        )

        #expect(openAIService.fetchModelsCallCount == 1)
        #expect(openAIService.lastFetchedAPIKey == "sk-test")
        #expect(apiKeysRepo.loadAPIKey() == "sk-test")
        #expect(settingsRepo.cachedModels.map(\.id) == ["gpt-4o", "gpt-4o-mini"])
        #expect(result.selectedModelID == "gpt-4o-mini")
        #expect(settingsRepo.selectedModelID == "gpt-4o-mini")
    }

    @Test
    func performValidateAndSaveAPIKey_fallsBackToFirstModelWhenSelectionMissing() async throws {
        let settingsRepo = InMemorySettingsRepository()
        let (useCase, _, _, _) = makeUseCase(settings: settingsRepo)

        let result = try await useCase.performValidateAndSaveAPIKey(
            trimmedToken: "sk-test",
            currentSelectedModelID: "missing-model"
        )

        #expect(result.selectedModelID == "gpt-4o")
        #expect(settingsRepo.selectedModelID == "gpt-4o")
    }

    @Test
    func performValidateAndSaveAPIKey_propagatesOpenAIError() async {
        let fake = SettingsFakeOpenAIServing()
        fake.errorToThrow = OpenAIServiceError.unauthorized
        let (useCase, _, apiKeys, _) = makeUseCase(openAI: fake)

        await #expect(throws: OpenAIServiceError.unauthorized) {
            try await useCase.performValidateAndSaveAPIKey(
                trimmedToken: "sk-test",
                currentSelectedModelID: nil
            )
        }
        #expect(apiKeys.loadAPIKey() == nil)
    }

    @Test
    func preflightRefreshModels_missingAPIKey() {
        let (useCase, _, _, _) = makeUseCase()

        if case .missingAPIKey = useCase.preflightRefreshModels() {
            #expect(Bool(true))
        } else {
            Issue.record("Expected missingAPIKey preflight")
        }
    }

    @Test
    func preflightRefreshModels_ready() throws {
        let apiKeys = InMemoryAPIKeyRepository()
        try apiKeys.saveAPIKey("sk-stored")
        let (useCase, _, _, _) = makeUseCase(apiKeys: apiKeys)

        if case .ready(let trimmed) = useCase.preflightRefreshModels() {
            #expect(trimmed == "sk-stored")
        } else {
            Issue.record("Expected ready preflight")
        }
    }

    @Test
    func performRefreshModels_usesStoredKey() async throws {
        let apiKeys = InMemoryAPIKeyRepository()
        try apiKeys.saveAPIKey("sk-stored")
        let openAIService = SettingsFakeOpenAIServing()
        let (useCase, settingsRepo, _, _) = makeUseCase(apiKeys: apiKeys, openAI: openAIService)

        let result = try await useCase.performRefreshModels(currentSelectedModelID: nil)

        #expect(openAIService.lastFetchedAPIKey == "sk-stored")
        #expect(result.models.count == 2)
        #expect(settingsRepo.selectedModelID == "gpt-4o")
    }

    @Test
    func deleteAPIKey_removesStoredKey() throws {
        let apiKeys = InMemoryAPIKeyRepository()
        try apiKeys.saveAPIKey("sk-test")
        let (useCase, _, _, _) = makeUseCase(apiKeys: apiKeys)

        try useCase.deleteAPIKey()

        #expect(apiKeys.loadAPIKey() == nil)
    }

    @Test
    func persistSettings_writeThroughRepository() {
        let settingsRepo = InMemorySettingsRepository()
        let (useCase, _, _, _) = makeUseCase(settings: settingsRepo)

        #expect(useCase.persistSelectedModelID("gpt-4o") == "gpt-4o")
        #expect(settingsRepo.selectedModelID == "gpt-4o")

        #expect(useCase.persistOCREngine(.ai) == .ai)
        #expect(settingsRepo.selectedOCREngineRawValue == OCREngine.ai.rawValue)

        #expect(useCase.persistDefaultNewProfileLearningLanguage(.chinese) == .chinese)
        #expect(settingsRepo.selectedLearningLanguageRawValue == LearningLanguage.chinese.rawValue)

        #expect(useCase.persistTranslationOverlayMinimumDuration(0.5) == 1)
        #expect(settingsRepo.translationOverlayMinimumDuration == 1)

        #expect(useCase.persistTranslationOverlaySecondsPerWord(5) == 2)
        #expect(settingsRepo.translationOverlaySecondsPerWord == 2)
    }

    @Test
    func resolveSelectedModelID_prefersExistingValidSelection() {
        let models = [OpenAIModel(id: "a"), OpenAIModel(id: "b")]

        #expect(
            ManageOpenAISettingsUseCase.resolveSelectedModelID(
                models: models,
                currentSelectedModelID: "b"
            ) == "b"
        )
        #expect(
            ManageOpenAISettingsUseCase.resolveSelectedModelID(
                models: models,
                currentSelectedModelID: "missing"
            ) == "a"
        )
    }

    @Test
    func persistSelectedTextProvider_isIsolatedFromOpenAIModel() {
        let settingsRepo = InMemorySettingsRepository()
        settingsRepo.selectedModelID = "gpt-4o"
        let (useCase, _, _, _) = makeUseCase(settings: settingsRepo)

        #expect(useCase.persistSelectedTextProvider(.deepSeek) == .deepSeek)
        #expect(settingsRepo.selectedTextProviderRawValue == AIProvider.deepSeek.rawValue)
        #expect(settingsRepo.selectedModelID == "gpt-4o")
    }

    @Test
    func performValidateAndSaveAPIKey_deepSeekDoesNotOverwriteOpenAIState() async throws {
        let settingsRepo = InMemorySettingsRepository()
        settingsRepo.selectedModelID = "gpt-4o"
        settingsRepo.cachedModels = [OpenAIModel(id: "gpt-4o")]
        let apiKeysRepo = InMemoryAPIKeyRepository()
        try apiKeysRepo.saveAPIKey("sk-openai", for: .openAI)
        let openAIService = SettingsFakeOpenAIServing()
        openAIService.modelsByProvider[.deepSeek] = [
            OpenAIModel(id: "deepseek-chat"),
            OpenAIModel(id: "deepseek-reasoner")
        ]
        let (useCase, _, _, _) = makeUseCase(
            settings: settingsRepo,
            apiKeys: apiKeysRepo,
            openAI: openAIService
        )

        let result = try await useCase.performValidateAndSaveAPIKey(
            trimmedToken: "sk-deepseek",
            currentSelectedModelID: nil,
            provider: .deepSeek
        )

        #expect(openAIService.lastFetchedProvider == .deepSeek)
        #expect(openAIService.lastFetchedAPIKey == "sk-deepseek")
        #expect(result.selectedModelID == "deepseek-chat")
        #expect(apiKeysRepo.loadAPIKey(for: .openAI) == "sk-openai")
        #expect(apiKeysRepo.loadAPIKey(for: .deepSeek) == "sk-deepseek")
        #expect(settingsRepo.selectedModelID == "gpt-4o")
        #expect(settingsRepo.cachedModels.map(\.id) == ["gpt-4o"])
        #expect(settingsRepo.selectedDeepSeekModelID == "deepseek-chat")
        #expect(settingsRepo.cachedDeepSeekModels.map(\.id) == ["deepseek-chat", "deepseek-reasoner"])
    }

    @Test
    func loadSettingsSnapshot_usesDeepSeekCacheWhenProviderIsDeepSeek() {
        let settings = InMemorySettingsRepository()
        settings.selectedTextProviderRawValue = AIProvider.deepSeek.rawValue
        settings.cachedModels = [OpenAIModel(id: "gpt-4o")]
        settings.selectedModelID = "gpt-4o"
        settings.cachedDeepSeekModels = [OpenAIModel(id: "deepseek-chat")]
        settings.selectedDeepSeekModelID = "deepseek-chat"
        let (useCase, _, _, _) = makeUseCase(settings: settings)

        let snapshot = useCase.loadSettingsSnapshot()

        #expect(snapshot.selectedTextProvider == .deepSeek)
        #expect(snapshot.selectedModelID == "deepseek-chat")
        #expect(snapshot.cachedModels.map(\.id) == ["deepseek-chat"])
    }

    @Test
    func deleteAPIKey_forDeepSeekLeavesOpenAIKey() throws {
        let apiKeys = InMemoryAPIKeyRepository()
        try apiKeys.saveAPIKey("sk-openai", for: .openAI)
        try apiKeys.saveAPIKey("sk-deepseek", for: .deepSeek)
        let (useCase, _, _, _) = makeUseCase(apiKeys: apiKeys)

        try useCase.deleteAPIKey(for: .deepSeek)

        #expect(apiKeys.loadAPIKey(for: .deepSeek) == nil)
        #expect(apiKeys.loadAPIKey(for: .openAI) == "sk-openai")
    }
}
