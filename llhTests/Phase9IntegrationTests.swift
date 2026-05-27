//
//  Phase9IntegrationTests.swift
//  llhTests
//

import CoreGraphics
import Foundation
import Testing
@testable import llh

struct Phase9IntegrationTests {
    @Test
    @MainActor
    func captureWorkflow_endToEndWithFakes() async throws {
        let image = Phase9TestSupport.makeTestCGImage()
        let useCase = CaptureRegionUseCase(
            permissionService: Phase9FakePermissionService(permissionStatus: .authorized),
            regionSelectionService: Phase9FakeRegionSelecting(),
            screenshotService: Phase9FakeScreenCapturing(image: image),
            recognizeTextUseCase: RecognizeTextUseCase(
                ocrService: Phase9FakeOCRServing(result: OCRResult(normalizedText: "captured line")),
                openAIOCRService: Phase9FakeOpenAIOCRServing(result: OCRResult(normalizedText: "unused"))
            )
        )

        let outcome = try await useCase.execute(
            configuration: CaptureRegionConfiguration(
                ocrEngine: .local,
                apiKey: nil,
                selectedModelID: nil
            )
        )

        guard case let .captured(capturedImage, text) = outcome else {
            Issue.record("Expected captured outcome, got \(outcome)")
            return
        }
        #expect(capturedImage.width == image.width)
        #expect(text == "captured line")
    }

    @Test
    @MainActor
    func formatWorkflow_persistsFormattedEntryThroughHistoryUseCase() async throws {
        let locations = Phase9TestSupport.makeTemporaryLocations()
        let database = try HistoryDatabase(locations: locations)
        let historyRepository = SQLiteHistoryRepository(database: database)
        let manageHistory = ManageHistoryUseCase(historyRepository: historyRepository)
        var state = try manageHistory.loadSession()

        let entry = CapturedTextEntry(text: "raw ocr", formattingStatus: .notRequested)
        manageHistory.insertEntry(state: &state, profileIndex: 0, entry: entry)
        try manageHistory.saveSession(state)

        let openAI = Phase9IntegrationFakeOpenAIServing()
        let formatUseCase = FormatCapturedTextUseCase(openAIService: openAI)
        let settings = Phase9InMemorySettingsRepository()
        let apiKeys = Phase9InMemoryAPIKeyRepository()

        let formatted = try await formatUseCase.perform(
            request: FormatCapturedTextRequest(
                rawText: "raw ocr",
                targetLanguage: .chinese,
                forceRetry: false,
                currentStatus: .notRequested,
                currentFormattedText: nil
            ),
            configuration: FormatCapturedTextConfiguration(
                apiKey: apiKeys.loadAPIKey(),
                modelID: settings.selectedModelID
            )
        )

        state = try manageHistory.loadSession()
        let updated = manageHistory.mutateEntry(
            state: &state,
            profileID: state.profiles[0].id,
            entryID: entry.id
        ) { mutable in
            mutable.formattedText = formatted
            mutable.formattingStatus = .succeeded
        }
        #expect(updated)
        try manageHistory.saveSession(state)

        let reloaded = try manageHistory.loadSession()
        let persisted = reloaded.profiles[0].history.first { $0.id == entry.id }
        #expect(persisted?.formattedText?.cleanedText == "cleaned")
        #expect(persisted?.formattingStatus == .succeeded)
        #expect(openAI.formatCallCount == 1)
        #expect(openAI.lastFormattedRawText == "raw ocr")
    }

    @Test
    @MainActor
    func settingsWorkflow_validateSaveAndReloadModels() async throws {
        let settings = Phase9InMemorySettingsRepository()
        let apiKeys = Phase9InMemoryAPIKeyRepository()
        let openAI = Phase9IntegrationFakeOpenAIServing()
        let useCase = ManageOpenAISettingsUseCase(
            settingsRepository: settings,
            apiKeyRepository: apiKeys,
            openAIService: openAI
        )

        switch useCase.preflightValidateAndSaveAPIKey("sk-integration-test") {
        case .ready(let trimmed):
            let result = try await useCase.performValidateAndSaveAPIKey(
                trimmedToken: trimmed,
                currentSelectedModelID: nil
            )
            #expect(result.models.count == 1)
            #expect(result.models[0].id == "gpt-4o-mini")
            #expect(result.selectedModelID == "gpt-4o-mini")
        default:
            Issue.record("Expected ready preflight")
        }

        let snapshot = useCase.loadSettingsSnapshot()
        #expect(snapshot.selectedModelID == "gpt-4o-mini")
        #expect(useCase.hasAPIKey())
        #expect(useCase.currentAPIKey() == "sk-integration-test")
    }

    @Test
    @MainActor
    func startupHistoryLoad_repairsInterruptedProcessingEntry() throws {
        let locations = Phase9TestSupport.makeTemporaryLocations()
        let database = try HistoryDatabase(locations: locations)
        let repository = SQLiteHistoryRepository(database: database)
        let interrupted = CapturedTextEntry(
            text: "unfinished",
            formattedText: nil,
            formattingStatus: .processing
        )
        let profile = LearningProfile.defaultProfile(
            history: [interrupted],
            selectedEntryID: interrupted.id
        )
        try repository.saveStore(
            HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)
        )

        let useCase = ManageHistoryUseCase(historyRepository: repository)
        let state = try useCase.loadSession()
        let entry = state.profiles[0].history[0]

        #expect(entry.formattingStatus == .failed)
        #expect(entry.formattedText == nil)
    }

    @Test
    @MainActor
    func appDependencyContainer_buildsMainViewModelWithInjectedFakes() throws {
        let locations = Phase9TestSupport.makeTemporaryLocations()
        let database = try HistoryDatabase(locations: locations)
        let historyRepository = SQLiteHistoryRepository(database: database)
        let manageHistoryUseCase = ManageHistoryUseCase(historyRepository: historyRepository)
        let settingsRepository = Phase9InMemorySettingsRepository()
        let apiKeyRepository = Phase9InMemoryAPIKeyRepository()
        let openAI = Phase9IntegrationFakeOpenAIServing()
        let permissionService = Phase9FakePermissionService(permissionStatus: .denied)
        let regionSelectionService = Phase9FakeRegionSelecting()
        let screenshotService = Phase9FakeScreenCapturing(image: Phase9TestSupport.makeTestCGImage())
        let ocrService = Phase9FakeOCRServing(result: OCRResult(normalizedText: "x"))
        let openAIOCRService = Phase9FakeOpenAIOCRServing(result: OCRResult(normalizedText: "x"))
        let (recognizeTextUseCase, captureRegionUseCase) = AppDependencyContainer.makeCaptureUseCases(
            permissionService: permissionService,
            regionSelectionService: regionSelectionService,
            screenshotService: screenshotService,
            ocrService: ocrService,
            openAIOCRService: openAIOCRService
        )

        let dependencies = AppDependencyContainer(
            historyRepository: historyRepository,
            settingsRepository: settingsRepository,
            apiKeyRepository: apiKeyRepository,
            permissionService: permissionService,
            regionSelectionService: regionSelectionService,
            screenshotService: screenshotService,
            ocrService: ocrService,
            openAIService: openAI,
            translationOverlayService: TranslationOverlayService(),
            recognizeTextUseCase: recognizeTextUseCase,
            captureRegionUseCase: captureRegionUseCase,
            formatCapturedTextUseCase: FormatCapturedTextUseCase(openAIService: openAI),
            manageHistoryUseCase: manageHistoryUseCase,
            manageProfilesUseCase: ManageProfilesUseCase(manageHistoryUseCase: manageHistoryUseCase),
            loadWordStudyUseCase: LoadWordStudyUseCase(openAIService: openAI),
            loadGrammarStudyUseCase: LoadGrammarStudyUseCase(openAIService: openAI),
            manageOpenAISettingsUseCase: ManageOpenAISettingsUseCase(
                settingsRepository: settingsRepository,
                apiKeyRepository: apiKeyRepository,
                openAIService: openAI
            )
        )

        let main = dependencies.makeMainViewModel()
        main.history.loadFromDisk()

        #expect(main.capture.permissionStatus == .denied)
        #expect(main.settings.hasOpenAIToken)
        #expect(main.history.profiles.isEmpty == false)
    }
}
