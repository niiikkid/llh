//
//  Phase3ManageOpenAISettingsUseCaseTests.swift
//  llhTests
//

import CoreGraphics
import Foundation
import Testing
@testable import llh

private final class InMemorySettingsRepository: SettingsRepository {
    var selectedModelID: String?
    var selectedLearningLanguageRawValue = LearningLanguage.english.rawValue
    var cachedModels: [OpenAIModel] = []
    var selectedOCREngineRawValue = OCREngine.local.rawValue
    var translationOverlayMinimumDuration = 3.0
    var translationOverlaySecondsPerWord = 0.33
}

private final class InMemoryAPIKeyRepository: APIKeyRepository {
    private var key: String?

    func loadAPIKey() -> String? {
        key
    }

    func saveAPIKey(_ key: String) throws {
        self.key = key
    }

    func deleteAPIKey() throws {
        key = nil
    }
}

private final class SettingsFakeOpenAIServing: OpenAIServing {
    var modelsToReturn: [OpenAIModel] = [
        OpenAIModel(id: "gpt-4o"),
        OpenAIModel(id: "gpt-4o-mini")
    ]
    var errorToThrow: Error?
    private(set) var fetchModelsCallCount = 0
    private(set) var lastFetchedAPIKey: String?

    func fetchModels(apiKey: String) async throws -> [OpenAIModel] {
        fetchModelsCallCount += 1
        lastFetchedAPIKey = apiKey
        if let errorToThrow {
            throw errorToThrow
        }
        return modelsToReturn
    }

    func recognizeTextInImage(apiKey: String, modelID: String, image: CGImage) async throws -> String {
        ""
    }

    func formatRecognizedText(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        StructuredFormattedText(cleanedText: "", pinyinText: nil, russianTranslation: "")
    }

    func buildWordsStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        WordStudyPayload(entries: [])
    }

    func buildPhrasesStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> PhraseStudyPayload {
        PhraseStudyPayload(entries: [])
    }

    func buildGrammarStudyData(
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
    func loadSettingsSnapshot_keepsStoredSelection() {
        let settings = InMemorySettingsRepository()
        settings.cachedModels = [OpenAIModel(id: "gpt-4o")]
        settings.selectedModelID = "gpt-4o-mini"
        let (useCase, _, _, _) = makeUseCase(settings: settings)

        let snapshot = useCase.loadSettingsSnapshot()

        #expect(snapshot.selectedModelID == "gpt-4o-mini")
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

        #expect(useCase.preflightValidateAndSaveAPIKey("   ") == .emptyToken)
    }

    @Test
    func preflightValidateAndSaveAPIKey_ready() {
        let (useCase, _, _, _) = makeUseCase()

        #expect(useCase.preflightValidateAndSaveAPIKey("  sk-test  ") == .ready(trimmedToken: "sk-test"))
    }

    @Test
    func performValidateAndSaveAPIKey_persistsModelsAndKeepsValidSelection() async throws {
        let settings = InMemorySettingsRepository()
        let apiKeys = InMemoryAPIKeyRepository()
        let fake = SettingsFakeOpenAIServing()
        let (useCase, settings, apiKeys, fake) = makeUseCase(
            settings: settings,
            apiKeys: apiKeys,
            openAI: fake
        )

        let result = try await useCase.performValidateAndSaveAPIKey(
            trimmedToken: "sk-test",
            currentSelectedModelID: "gpt-4o-mini"
        )

        #expect(fake.fetchModelsCallCount == 1)
        #expect(fake.lastFetchedAPIKey == "sk-test")
        #expect(apiKeys.loadAPIKey() == "sk-test")
        #expect(settings.cachedModels.map(\.id) == ["gpt-4o", "gpt-4o-mini"])
        #expect(result.selectedModelID == "gpt-4o-mini")
        #expect(settings.selectedModelID == "gpt-4o-mini")
    }

    @Test
    func performValidateAndSaveAPIKey_fallsBackToFirstModelWhenSelectionMissing() async throws {
        let settings = InMemorySettingsRepository()
        let (useCase, settings, _, _) = makeUseCase(settings: settings)

        let result = try await useCase.performValidateAndSaveAPIKey(
            trimmedToken: "sk-test",
            currentSelectedModelID: "missing-model"
        )

        #expect(result.selectedModelID == "gpt-4o")
        #expect(settings.selectedModelID == "gpt-4o")
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

        #expect(useCase.preflightRefreshModels() == .missingAPIKey)
    }

    @Test
    func preflightRefreshModels_ready() throws {
        let apiKeys = InMemoryAPIKeyRepository()
        try apiKeys.saveAPIKey("sk-stored")
        let (useCase, _, _, _) = makeUseCase(apiKeys: apiKeys)

        #expect(useCase.preflightRefreshModels() == .ready(trimmedToken: "sk-stored"))
    }

    @Test
    func performRefreshModels_usesStoredKey() async throws {
        let apiKeys = InMemoryAPIKeyRepository()
        try apiKeys.saveAPIKey("sk-stored")
        let fake = SettingsFakeOpenAIServing()
        let (useCase, settings, _, fake) = makeUseCase(apiKeys: apiKeys, openAI: fake)

        let result = try await useCase.performRefreshModels(currentSelectedModelID: nil)

        #expect(fake.lastFetchedAPIKey == "sk-stored")
        #expect(result.models.count == 2)
        #expect(settings.selectedModelID == "gpt-4o")
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
        let settings = InMemorySettingsRepository()
        let (useCase, settings, _, _) = makeUseCase(settings: settings)

        #expect(useCase.persistSelectedModelID("gpt-4o") == "gpt-4o")
        #expect(settings.selectedModelID == "gpt-4o")

        #expect(useCase.persistOCREngine(.openai) == .openai)
        #expect(settings.selectedOCREngineRawValue == OCREngine.openai.rawValue)

        #expect(useCase.persistDefaultNewProfileLearningLanguage(.chinese) == .chinese)
        #expect(settings.selectedLearningLanguageRawValue == LearningLanguage.chinese.rawValue)

        #expect(useCase.persistTranslationOverlayMinimumDuration(0.5) == 1)
        #expect(settings.translationOverlayMinimumDuration == 1)

        #expect(useCase.persistTranslationOverlaySecondsPerWord(5) == 2)
        #expect(settings.translationOverlaySecondsPerWord == 2)
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
}
