//
//  SettingsViewModel.swift
//  llh
//

import AppKit
import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedTextProvider: AIProvider = .openAI
    @Published private(set) var availableTextModels: [OpenAIModel] = []
    @Published var selectedTextModelID: String?
    @Published var selectedOCREngine: OCREngine = .local
    @Published var defaultNewProfileLearningLanguage: LearningLanguage = .english
    @Published var translationOverlayMinimumDuration: Double = 3
    @Published var translationOverlaySecondsPerWord: Double = 0.33
    @Published private(set) var isLoadingModels = false
    @Published private(set) var statusMessage = ""

    private let manageOpenAISettingsUseCase: ManageOpenAISettingsUseCase
    private let translationOverlayService: TranslationOverlayService

    init(
        manageOpenAISettingsUseCase: ManageOpenAISettingsUseCase,
        translationOverlayService: TranslationOverlayService
    ) {
        self.manageOpenAISettingsUseCase = manageOpenAISettingsUseCase
        self.translationOverlayService = translationOverlayService
        applySnapshot(manageOpenAISettingsUseCase.loadSettingsSnapshot())
    }

    var hasOpenAIToken: Bool {
        hasToken(for: .openAI)
    }

    var hasDeepSeekToken: Bool {
        hasToken(for: .deepSeek)
    }

    func hasToken(for provider: AIProvider) -> Bool {
        manageOpenAISettingsUseCase.hasAPIKey(for: provider)
    }

    func textAPIKey() -> String? {
        manageOpenAISettingsUseCase.currentAPIKey(for: selectedTextProvider)
    }

    func textModelID() -> String? {
        selectedTextModelID
    }

    func openAIAPIKey() -> String? {
        manageOpenAISettingsUseCase.currentAPIKey(for: .openAI)
    }

    func openAIModelID() -> String? {
        manageOpenAISettingsUseCase.selectedModelID(for: .openAI)
    }

    func validateAndSaveToken(_ token: String, for provider: AIProvider) async {
        switch manageOpenAISettingsUseCase.preflightValidateAndSaveAPIKey(token) {
        case .emptyToken:
            publishStatus("Введите token \(provider.title).")
            return
        case let .ready(trimmedToken):
            isLoadingModels = true
            defer { isLoadingModels = false }

            do {
                let currentModelID = provider == selectedTextProvider
                    ? selectedTextModelID
                    : manageOpenAISettingsUseCase.selectedModelID(for: provider)
                let result = try await manageOpenAISettingsUseCase.performValidateAndSaveAPIKey(
                    trimmedToken: trimmedToken,
                    currentSelectedModelID: currentModelID,
                    provider: provider
                )
                if provider == selectedTextProvider {
                    availableTextModels = result.models
                    selectedTextModelID = result.selectedModelID
                }
                publishStatus("Подключение к \(provider.title) успешно. Моделей: \(result.models.count).")
            } catch {
                publishStatus("\(provider.title): \(error.localizedDescription)")
            }
        }
    }

    func refreshModels(for provider: AIProvider) async {
        switch manageOpenAISettingsUseCase.preflightRefreshModels(for: provider) {
        case .missingAPIKey:
            publishStatus("Сначала сохраните token \(provider.title).")
        case let .ready(trimmedToken):
            await validateAndSaveToken(trimmedToken, for: provider)
        }
    }

    func deleteToken(for provider: AIProvider) {
        do {
            try manageOpenAISettingsUseCase.deleteAPIKey(for: provider)
            publishStatus("Токен \(provider.title) удален.")
        } catch {
            publishStatus("Не удалось удалить token \(provider.title): \(error.localizedDescription)")
        }
    }

    func selectTextProvider(_ provider: AIProvider) {
        selectedTextProvider = manageOpenAISettingsUseCase.persistSelectedTextProvider(provider)
        applyModels(for: provider)
        publishStatus("Провайдер текста: \(provider.title).")
    }

    func selectTextModel(_ id: String?) {
        selectedTextModelID = manageOpenAISettingsUseCase.persistSelectedModelID(id, for: selectedTextProvider)
        if let id {
            publishStatus("Выбрана модель \(selectedTextProvider.title): \(id)")
        }
    }

    func selectOCREngine(_ engine: OCREngine, showOverlay: Bool = false) {
        let previousEngine = selectedOCREngine
        selectedOCREngine = manageOpenAISettingsUseCase.persistOCREngine(engine)
        publishStatus("Движок распознавания: \(engine.title).")
        guard showOverlay, shouldUseCompactOverlay else { return }
        translationOverlayService.showMessage(
            title: previousEngine.title + " ->",
            subtitle: engine.title,
            duration: 1.5
        )
    }

    func switchToNextOCREngine(triggeredByHotkey: Bool = false) {
        guard let currentIndex = OCREngine.allCases.firstIndex(of: selectedOCREngine) else {
            selectOCREngine(.local, showOverlay: triggeredByHotkey)
            return
        }
        let nextIndex = OCREngine.allCases.index(after: currentIndex)
        let wrappedIndex = nextIndex == OCREngine.allCases.endIndex ? OCREngine.allCases.startIndex : nextIndex
        selectOCREngine(OCREngine.allCases[wrappedIndex], showOverlay: triggeredByHotkey)
    }

    func setDefaultNewProfileLearningLanguage(_ language: LearningLanguage) {
        defaultNewProfileLearningLanguage = manageOpenAISettingsUseCase.persistDefaultNewProfileLearningLanguage(language)
    }

    func setTranslationOverlayMinimumDuration(_ duration: Double) {
        translationOverlayMinimumDuration = manageOpenAISettingsUseCase.persistTranslationOverlayMinimumDuration(duration)
    }

    func setTranslationOverlaySecondsPerWord(_ value: Double) {
        translationOverlaySecondsPerWord = manageOpenAISettingsUseCase.persistTranslationOverlaySecondsPerWord(value)
    }

    func calculatedTranslationOverlayDuration(for formattedText: StructuredFormattedText) -> Double {
        TranslationOverlayTiming.duration(
            for: formattedText,
            minimumDuration: translationOverlayMinimumDuration,
            secondsPerWord: translationOverlaySecondsPerWord
        )
    }

    private func applySnapshot(_ snapshot: OpenAISettingsSnapshot) {
        selectedTextProvider = snapshot.selectedTextProvider
        availableTextModels = snapshot.cachedModels
        selectedTextModelID = snapshot.selectedModelID
        selectedOCREngine = snapshot.selectedOCREngine
        defaultNewProfileLearningLanguage = snapshot.defaultNewProfileLearningLanguage
        translationOverlayMinimumDuration = snapshot.translationOverlayMinimumDuration
        translationOverlaySecondsPerWord = snapshot.translationOverlaySecondsPerWord
    }

    private func applyModels(for provider: AIProvider) {
        let models = manageOpenAISettingsUseCase.cachedModels(for: provider)
        availableTextModels = models
        selectedTextModelID = ManageOpenAISettingsUseCase.resolveSelectedModelID(
            models: models,
            currentSelectedModelID: manageOpenAISettingsUseCase.selectedModelID(for: provider)
        )
    }

    private var shouldUseCompactOverlay: Bool {
        !NSApp.isActive
    }

    private func publishStatus(_ message: String) {
        statusMessage = message
    }
}
