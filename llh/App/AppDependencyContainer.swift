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
    let transcribeSpeechUseCase: TranscribeSpeechUseCase
    let askTranslationChatUseCase: AskTranslationChatUseCase
    let microphoneRecorder: any MicrophoneRecording

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
        manageOpenAISettingsUseCase: ManageOpenAISettingsUseCase,
        transcribeSpeechUseCase: TranscribeSpeechUseCase? = nil,
        askTranslationChatUseCase: AskTranslationChatUseCase? = nil,
        microphoneRecorder: (any MicrophoneRecording)? = nil
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
        self.transcribeSpeechUseCase = transcribeSpeechUseCase ?? TranscribeSpeechUseCase(
            service: OpenAITranscriptionService(httpClient: OpenAIHTTPClient())
        )
        self.askTranslationChatUseCase = askTranslationChatUseCase ?? AskTranslationChatUseCase(
            service: OpenAITranslationChatService(
                openAIHTTPClient: OpenAIHTTPClient(),
                deepSeekHTTPClient: OpenAIHTTPClient(baseURL: AIProvider.deepSeek.apiBaseURL)
            )
        )
        self.microphoneRecorder = microphoneRecorder ?? AVAudioMicrophoneRecorder()
    }

    static func live() -> AppDependencyContainer {
        let permissionService = ScreenRecordingPermissionService()
        let regionSelectionService = RegionSelectionService()
        let screenshotService = ScreenCaptureKitCaptureService()
        let ocrService = VisionOCRService()
        let openAIClient = OpenAIHTTPClient(baseURL: AIProvider.openAI.apiBaseURL)
        let deepSeekClient = OpenAIHTTPClient(baseURL: AIProvider.deepSeek.apiBaseURL)
        let openAIOCRService = OpenAIOCRService(httpClient: openAIClient)
        let openAIService = OpenAIService(
            openAIHTTPClient: openAIClient,
            deepSeekHTTPClient: deepSeekClient,
            ocrService: openAIOCRService
        )
        let (recognizeTextUseCase, captureRegionUseCase) = makeCaptureUseCases(
            permissionService: permissionService,
            regionSelectionService: regionSelectionService,
            screenshotService: screenshotService,
            ocrService: ocrService,
            openAIOCRService: openAIOCRService
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
            manageOpenAISettingsUseCase: manageOpenAISettingsUseCase,
            transcribeSpeechUseCase: TranscribeSpeechUseCase(
                service: OpenAITranscriptionService(httpClient: openAIClient)
            ),
            askTranslationChatUseCase: AskTranslationChatUseCase(
                service: OpenAITranslationChatService(
                    openAIHTTPClient: openAIClient,
                    deepSeekHTTPClient: deepSeekClient
                )
            ),
            microphoneRecorder: AVAudioMicrophoneRecorder()
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
        openAIOCRService: OpenAIOCRServing
    ) -> (RecognizeTextUseCase, CaptureRegionUseCase) {
        let recognizeTextUseCase = RecognizeTextUseCase(
            ocrService: ocrService,
            openAIOCRService: openAIOCRService
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
