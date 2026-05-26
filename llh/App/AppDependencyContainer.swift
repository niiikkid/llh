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

    init(
        historyRepository: HistoryRepository,
        settingsRepository: SettingsRepository,
        apiKeyRepository: APIKeyRepository,
        permissionService: ScreenRecordingPermissionChecking,
        regionSelectionService: RegionSelecting,
        screenshotService: ScreenCapturing,
        ocrService: OCRServing,
        openAIService: OpenAIServing,
        translationOverlayService: TranslationOverlayService
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
    }

    static func live() -> AppDependencyContainer {
        AppDependencyContainer(
            historyRepository: JSONHistoryRepository(),
            settingsRepository: UserDefaultsSettingsRepository(),
            apiKeyRepository: KeychainAPIKeyRepository(),
            permissionService: ScreenRecordingPermissionService(),
            regionSelectionService: RegionSelectionService(),
            screenshotService: ScreenshotService(),
            ocrService: OCRService(),
            openAIService: OpenAIService(),
            translationOverlayService: TranslationOverlayService()
        )
    }

    func makeMainViewModel() -> MainViewModel {
        MainViewModel(dependencies: self)
    }
}
