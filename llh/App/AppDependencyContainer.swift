//
//  AppDependencyContainer.swift
//  llh
//

import Foundation

@MainActor
struct AppDependencyContainer {
    let historyRepository: HistoryRepository
    let settingsRepository: SettingsRepository
    let apiKeyRepository: APIKeyRepository
    let permissionService: ScreenRecordingPermissionChecking
    let regionSelectionService: RegionSelecting
    let screenshotService: ScreenCapturing
    let ocrService: OCRServing
    let openAIService: OpenAIServing
    let translationOverlayService: TranslationOverlayService
    let recognizeTextUseCase: RecognizeTextUseCase
    let captureRegionUseCase: CaptureRegionUseCase
    let formatCapturedTextUseCase: FormatCapturedTextUseCase
    let manageHistoryUseCase: ManageHistoryUseCase
    let manageProfilesUseCase: ManageProfilesUseCase
    let loadWordStudyUseCase: LoadWordStudyUseCase
    let manageOpenAISettingsUseCase: ManageOpenAISettingsUseCase

    init(
        historyRepository: HistoryRepository,
        settingsRepository: SettingsRepository,
        apiKeyRepository: APIKeyRepository,
        permissionService: ScreenRecordingPermissionChecking,
        regionSelectionService: RegionSelecting,
        screenshotService: ScreenCapturing,
        ocrService: OCRServing,
        openAIService: OpenAIServing,
        translationOverlayService: TranslationOverlayService,
        recognizeTextUseCase: RecognizeTextUseCase,
        captureRegionUseCase: CaptureRegionUseCase,
        formatCapturedTextUseCase: FormatCapturedTextUseCase,
        manageHistoryUseCase: ManageHistoryUseCase,
        manageProfilesUseCase: ManageProfilesUseCase,
        loadWordStudyUseCase: LoadWordStudyUseCase,
        manageOpenAISettingsUseCase: ManageOpenAISettingsUseCase
    ) {
        self.historyRepository = historyRepository
        self.settingsRepository = settingsRepository
        self.apiKeyRepository = apiKeyRepository
        self.permissionService = permissionService
        self.regionSelectionService = regionSelectionService
        self.screenshotService = screenshotService
        self.ocrService = ocrService
        self.openAIService = openAIService
        self.translationOverlayService = translationOverlayService
        self.recognizeTextUseCase = recognizeTextUseCase
        self.captureRegionUseCase = captureRegionUseCase
        self.formatCapturedTextUseCase = formatCapturedTextUseCase
        self.manageHistoryUseCase = manageHistoryUseCase
        self.manageProfilesUseCase = manageProfilesUseCase
        self.loadWordStudyUseCase = loadWordStudyUseCase
        self.manageOpenAISettingsUseCase = manageOpenAISettingsUseCase
    }

    static func live() -> AppDependencyContainer {
        let permissionService = ScreenRecordingPermissionService()
        let regionSelectionService = RegionSelectionService()
        let screenshotService = ScreenshotService()
        let ocrService = OCRService()
        let openAIService = OpenAIService()
        let (recognizeTextUseCase, captureRegionUseCase) = makeCaptureUseCases(
            permissionService: permissionService,
            regionSelectionService: regionSelectionService,
            screenshotService: screenshotService,
            ocrService: ocrService,
            openAIService: openAIService
        )
        let formatCapturedTextUseCase = FormatCapturedTextUseCase(openAIService: openAIService)
        let historyRepository = HistoryRepositoryBootstrap.makeRepository()
        let manageHistoryUseCase = ManageHistoryUseCase(historyRepository: historyRepository)
        let manageProfilesUseCase = ManageProfilesUseCase(manageHistoryUseCase: manageHistoryUseCase)
        let loadWordStudyUseCase = LoadWordStudyUseCase(openAIService: openAIService)
        let settingsRepository = UserDefaultsSettingsRepository()
        let apiKeyRepository = KeychainAPIKeyRepository()
        let manageOpenAISettingsUseCase = ManageOpenAISettingsUseCase(
            settingsRepository: settingsRepository,
            apiKeyRepository: apiKeyRepository,
            openAIService: openAIService
        )

        return AppDependencyContainer(
            historyRepository: historyRepository,
            settingsRepository: settingsRepository,
            apiKeyRepository: apiKeyRepository,
            permissionService: permissionService,
            regionSelectionService: regionSelectionService,
            screenshotService: screenshotService,
            ocrService: ocrService,
            openAIService: openAIService,
            translationOverlayService: TranslationOverlayService(),
            recognizeTextUseCase: recognizeTextUseCase,
            captureRegionUseCase: captureRegionUseCase,
            formatCapturedTextUseCase: formatCapturedTextUseCase,
            manageHistoryUseCase: manageHistoryUseCase,
            manageProfilesUseCase: manageProfilesUseCase,
            loadWordStudyUseCase: loadWordStudyUseCase,
            manageOpenAISettingsUseCase: manageOpenAISettingsUseCase
        )
    }

    func makeMainViewModel() -> MainViewModel {
        MainViewModel(dependencies: self)
    }

    /// Builds capture use cases from the same service instances passed to the container.
    static func makeCaptureUseCases(
        permissionService: ScreenRecordingPermissionChecking,
        regionSelectionService: RegionSelecting,
        screenshotService: ScreenCapturing,
        ocrService: OCRServing,
        openAIService: OpenAIServing
    ) -> (RecognizeTextUseCase, CaptureRegionUseCase) {
        let recognizeTextUseCase = RecognizeTextUseCase(
            ocrService: ocrService,
            openAIService: openAIService
        )
        let captureRegionUseCase = CaptureRegionUseCase(
            permissionService: permissionService,
            regionSelectionService: regionSelectionService,
            screenshotService: screenshotService,
            recognizeTextUseCase: recognizeTextUseCase
        )
        return (recognizeTextUseCase, captureRegionUseCase)
    }
}
