//
//  Phase1RepositoryTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase1RepositoryTests {
    @Test
    func jsonHistoryRepository_roundtripsThroughPersistenceService() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("history.json", isDirectory: false)
        let persistence = HistoryPersistenceService(fileURL: fileURL)
        let repository = JSONHistoryRepository(persistence: persistence)
        let profile = LearningProfile.defaultProfile(
            history: [CapturedTextEntry(text: "你好")],
            selectedEntryID: nil
        )
        let snapshot = HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)

        try repository.saveStore(snapshot)
        let loaded = try repository.loadStore()

        #expect(loaded.profiles.count == 1)
        #expect(loaded.profiles[0].history.first?.text == "你好")
        #expect(loaded.selectedProfileID == profile.id)
    }

    @Test
    func userDefaultsSettingsRepository_persistsOCREngineSelection() {
        let defaults = UserDefaults(suiteName: "llh.tests.\(UUID().uuidString)")!
        let store = OpenAISettingsStore(
            userDefaults: defaults,
            selectedOCREngineKey: "ocr.engine.test"
        )
        var repository = UserDefaultsSettingsRepository(store: store)

        repository.selectedOCREngineRawValue = "openai"
        let reloaded = UserDefaultsSettingsRepository(store: store)

        #expect(reloaded.selectedOCREngineRawValue == "openai")
    }

    @Test
    func keychainAPIKeyRepository_delegatesToTokenStore() throws {
        let store = InMemoryOpenAITokenStore()
        let repository = KeychainAPIKeyRepository(tokenStore: store)

        try repository.saveAPIKey("sk-test")
        #expect(repository.loadAPIKey() == "sk-test")
        try repository.deleteAPIKey()
        #expect(repository.loadAPIKey() == nil)
    }

    @Test
    @MainActor
    func mainViewModel_acceptsInjectedRepositories() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("history.json", isDirectory: false)
        let defaults = UserDefaults(suiteName: "llh.tests.\(UUID().uuidString)")!
        let permissionService = ScreenRecordingPermissionService()
        let regionSelectionService = RegionSelectionService()
        let screenshotService = ScreenshotService()
        let ocrService = OCRService()
        let openAIService = OpenAIService()
        let (recognizeTextUseCase, captureRegionUseCase) = AppDependencyContainer.makeCaptureUseCases(
            permissionService: permissionService,
            regionSelectionService: regionSelectionService,
            screenshotService: screenshotService,
            ocrService: ocrService,
            openAIService: openAIService
        )
        let dependencies = AppDependencyContainer(
            historyRepository: JSONHistoryRepository(
                persistence: HistoryPersistenceService(fileURL: fileURL)
            ),
            settingsRepository: UserDefaultsSettingsRepository(
                store: OpenAISettingsStore(userDefaults: defaults)
            ),
            apiKeyRepository: KeychainAPIKeyRepository(tokenStore: InMemoryOpenAITokenStore()),
            permissionService: permissionService,
            regionSelectionService: regionSelectionService,
            screenshotService: screenshotService,
            ocrService: ocrService,
            openAIService: openAIService,
            translationOverlayService: TranslationOverlayService(),
            recognizeTextUseCase: recognizeTextUseCase,
            captureRegionUseCase: captureRegionUseCase
        )
        let viewModel = dependencies.makeMainViewModel()

        #expect(viewModel.hasOpenAIToken == false)
        #expect(viewModel.profiles.isEmpty == false)
    }
}

private final class InMemoryOpenAITokenStore: OpenAITokenStoring {
    private var token: String?

    func loadToken() -> String? {
        token
    }

    func saveToken(_ token: String) throws {
        self.token = token
    }

    func deleteToken() throws {
        token = nil
    }
}
