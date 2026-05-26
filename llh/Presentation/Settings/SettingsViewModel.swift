//
//  SettingsViewModel.swift
//  llh
//

import AppKit
import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var availableOpenAIModels: [OpenAIModel] = []
    @Published var selectedOpenAIModelID: String?
    @Published var selectedOCREngine: OCREngine = .local
    @Published var defaultNewProfileLearningLanguage: LearningLanguage = .english
    @Published var translationOverlayMinimumDuration: Double = 3
    @Published var translationOverlaySecondsPerWord: Double = 0.33
    @Published private(set) var isLoadingOpenAIModels = false
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
        manageOpenAISettingsUseCase.hasAPIKey()
    }

    func currentAPIKey() -> String? {
        manageOpenAISettingsUseCase.currentAPIKey()
    }

    func validateAndSaveOpenAIToken(_ token: String) async {
        switch manageOpenAISettingsUseCase.preflightValidateAndSaveAPIKey(token) {
        case .emptyToken:
            publishStatus("Введите OpenAI token.")
            return
        case let .ready(trimmedToken):
            isLoadingOpenAIModels = true
            defer { isLoadingOpenAIModels = false }

            do {
                let result = try await manageOpenAISettingsUseCase.performValidateAndSaveAPIKey(
                    trimmedToken: trimmedToken,
                    currentSelectedModelID: selectedOpenAIModelID
                )
                availableOpenAIModels = result.models
                selectedOpenAIModelID = result.selectedModelID
                publishStatus("Подключение к OpenAI успешно. Моделей: \(result.models.count).")
            } catch {
                publishStatus("OpenAI: \(error.localizedDescription)")
            }
        }
    }

    func refreshOpenAIModels() async {
        switch manageOpenAISettingsUseCase.preflightRefreshModels() {
        case .missingAPIKey:
            publishStatus("Сначала сохраните OpenAI token.")
        case let .ready(trimmedToken):
            await validateAndSaveOpenAIToken(trimmedToken)
        }
    }

    func deleteOpenAIToken() {
        do {
            try manageOpenAISettingsUseCase.deleteAPIKey()
            publishStatus("Токен OpenAI удален.")
        } catch {
            publishStatus("Не удалось удалить OpenAI token: \(error.localizedDescription)")
        }
    }

    func selectOpenAIModel(_ id: String?) {
        selectedOpenAIModelID = manageOpenAISettingsUseCase.persistSelectedModelID(id)
        if let id {
            publishStatus("Выбрана модель OpenAI: \(id)")
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
        availableOpenAIModels = snapshot.cachedModels
        selectedOpenAIModelID = snapshot.selectedModelID
        selectedOCREngine = snapshot.selectedOCREngine
        defaultNewProfileLearningLanguage = snapshot.defaultNewProfileLearningLanguage
        translationOverlayMinimumDuration = snapshot.translationOverlayMinimumDuration
        translationOverlaySecondsPerWord = snapshot.translationOverlaySecondsPerWord
    }

    private var shouldUseCompactOverlay: Bool {
        !NSApp.isActive
    }

    private func publishStatus(_ message: String) {
        statusMessage = message
    }
}
