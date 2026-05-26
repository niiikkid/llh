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
        captureRegionUseCase: CaptureRegionUseCase
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

        return AppDependencyContainer(
            historyRepository: JSONHistoryRepository(),
            settingsRepository: UserDefaultsSettingsRepository(),
            apiKeyRepository: KeychainAPIKeyRepository(),
            permissionService: permissionService,
            regionSelectionService: regionSelectionService,
            screenshotService: screenshotService,
            ocrService: ocrService,
            openAIService: openAIService,
            translationOverlayService: TranslationOverlayService(),
            recognizeTextUseCase: recognizeTextUseCase,
            captureRegionUseCase: captureRegionUseCase
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
