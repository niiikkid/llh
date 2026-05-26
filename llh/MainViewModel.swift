//
//  MainViewModel.swift
//  llh
//

import AppKit
import Combine
import Foundation
import KeyboardShortcuts

@MainActor
final class MainViewModel: ObservableObject {
    enum CaptureTriggerSource {
        case interface
        case hotkey
    }

    @Published var recognizedText = ""
    @Published var formattedRecognizedText: StructuredFormattedText?
    @Published var studyMaterials = StudyMaterials()
    @Published var capturedImage: NSImage?
    @Published var statusMessage = "Нажмите shortcut и выделите область."
    @Published var showPermissionHelp = false
    @Published var isProcessing = false
    @Published private(set) var profiles: [LearningProfile] = []
    @Published var selectedProfileID: LearningProfile.ID?
    @Published var selectedEntryID: CapturedTextEntry.ID?
    @Published private(set) var availableOpenAIModels: [OpenAIModel] = []
    @Published var selectedOpenAIModelID: String?
    @Published var selectedOCREngine: OCREngine = .local
    @Published var defaultNewProfileLearningLanguage: LearningLanguage = .english
    @Published var translationOverlayMinimumDuration: Double = 3
    @Published var translationOverlaySecondsPerWord: Double = 0.33
    @Published private(set) var isLoadingOpenAIModels = false
    @Published private(set) var isFormattingRecognizedText = false
    @Published private(set) var showsSessionReadingOverview = false

    private let permissionService: ScreenRecordingPermissionChecking
    private let regionSelectionService: RegionSelecting
    private let screenshotService: ScreenCapturing
    private let ocrService: OCRServing
    private let historyRepository: HistoryRepository
    private let openAIService: OpenAIServing
    private let translationOverlayService: TranslationOverlayService
    private var settingsRepository: SettingsRepository
    private let apiKeyRepository: APIKeyRepository
    private var overlayEntryAwaitingFormattedResult: CapturedTextEntry.ID?

    init(dependencies: AppDependencyContainer) {
        permissionService = dependencies.permissionService
        regionSelectionService = dependencies.regionSelectionService
        screenshotService = dependencies.screenshotService
        ocrService = dependencies.ocrService
        historyRepository = dependencies.historyRepository
        openAIService = dependencies.openAIService
        translationOverlayService = dependencies.translationOverlayService
        settingsRepository = dependencies.settingsRepository
        apiKeyRepository = dependencies.apiKeyRepository
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [weak self] in
            Task { @MainActor [weak self] in
                self?.closeTranslationOverlay()
                await self?.startCaptureFlow(triggeredBy: .hotkey)
            }
        }
        KeyboardShortcuts.onKeyUp(for: .switchOCREngine) { [weak self] in
            Task { @MainActor [weak self] in
                self?.closeTranslationOverlay(cancelPendingResult: false)
                self?.switchToNextOCREngine(triggeredByHotkey: true)
            }
        }
        KeyboardShortcuts.onKeyUp(for: .closeTranslationOverlay) { [weak self] in
            Task { @MainActor [weak self] in
                self?.closeTranslationOverlay()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .toggleLastTranslationOverlay) { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggleLastTranslationOverlay()
            }
        }
        loadHistory()
        availableOpenAIModels = settingsRepository.cachedModels
        selectedOpenAIModelID = settingsRepository.selectedModelID
        selectedOCREngine = OCREngine(rawValue: settingsRepository.selectedOCREngineRawValue) ?? .local
        if selectedOpenAIModelID == nil {
            selectedOpenAIModelID = availableOpenAIModels.first?.id
        }
        defaultNewProfileLearningLanguage = LearningLanguage(rawValue: settingsRepository.selectedLearningLanguageRawValue) ?? .english
        translationOverlayMinimumDuration = settingsRepository.translationOverlayMinimumDuration
        translationOverlaySecondsPerWord = settingsRepository.translationOverlaySecondsPerWord
        refreshPermissionState()
    }

    var hasOpenAIToken: Bool {
        apiKeyRepository.loadAPIKey() != nil
    }

    func validateAndSaveOpenAIToken(_ token: String) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            statusMessage = "Введите OpenAI token."
            return
        }

        isLoadingOpenAIModels = true
        defer { isLoadingOpenAIModels = false }

        do {
            let models = try await openAIService.fetchModels(apiKey: trimmedToken)
            try apiKeyRepository.saveAPIKey(trimmedToken)
            availableOpenAIModels = models
            settingsRepository.cachedModels = models

            if let selectedOpenAIModelID,
               models.contains(where: { $0.id == selectedOpenAIModelID }) {
                // Keep current selection.
            } else {
                selectedOpenAIModelID = models.first?.id
            }
            settingsRepository.selectedModelID = selectedOpenAIModelID

            statusMessage = "Подключение к OpenAI успешно. Моделей: \(models.count)."
        } catch {
            statusMessage = "OpenAI: \(error.localizedDescription)"
        }
    }

    func refreshOpenAIModels() async {
        guard let token = apiKeyRepository.loadAPIKey() else {
            statusMessage = "Сначала сохраните OpenAI token."
            return
        }
        await validateAndSaveOpenAIToken(token)
    }

    func deleteOpenAIToken() {
        do {
            try apiKeyRepository.deleteAPIKey()
            statusMessage = "Токен OpenAI удален."
        } catch {
            statusMessage = "Не удалось удалить OpenAI token: \(error.localizedDescription)"
        }
    }

    func selectOpenAIModel(_ id: String?) {
        selectedOpenAIModelID = id
        settingsRepository.selectedModelID = id
        if let id {
            statusMessage = "Выбрана модель OpenAI: \(id)"
        }
    }

    func selectOCREngine(_ engine: OCREngine, showOverlay: Bool = false) {
        let previousEngine = selectedOCREngine
        selectedOCREngine = engine
        settingsRepository.selectedOCREngineRawValue = engine.rawValue
        statusMessage = "Движок распознавания: \(engine.title)."
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
        defaultNewProfileLearningLanguage = language
        settingsRepository.selectedLearningLanguageRawValue = language.rawValue
    }

    func setTranslationOverlayMinimumDuration(_ duration: Double) {
        let clampedDuration = min(max(duration, 1), 15)
        translationOverlayMinimumDuration = clampedDuration
        settingsRepository.translationOverlayMinimumDuration = clampedDuration
    }

    func setTranslationOverlaySecondsPerWord(_ value: Double) {
        let clampedValue = min(max(value, 0.1), 2)
        translationOverlaySecondsPerWord = clampedValue
        settingsRepository.translationOverlaySecondsPerWord = clampedValue
    }

    func calculatedTranslationOverlayDuration(for formattedText: StructuredFormattedText) -> Double {
        TranslationOverlayTiming.duration(
            for: formattedText,
            minimumDuration: translationOverlayMinimumDuration,
            secondsPerWord: translationOverlaySecondsPerWord
        )
    }

    var currentProfileLearningLanguage: LearningLanguage {
        activeProfile?.learningLanguage ?? defaultNewProfileLearningLanguage
    }

    var currentProfileSupportsWordStudy: Bool {
        currentProfileLearningLanguage.supportsWordStudy
    }

    func triggerCapture() {
        Task {
            closeTranslationOverlay()
            await startCaptureFlow(triggeredBy: .interface)
        }
    }

    func closeTranslationOverlay(cancelPendingResult: Bool = true) {
        if cancelPendingResult {
            overlayEntryAwaitingFormattedResult = nil
        }
        translationOverlayService.hide()
    }

    func toggleLastTranslationOverlay() {
        if translationOverlayService.isShowingPersistentLastTranslation {
            closeTranslationOverlay()
            return
        }

        overlayEntryAwaitingFormattedResult = nil

        guard let formattedText = LatestTranslationLookup.latestFormattedText(in: profiles) else {
            translationOverlayService.showMessage(title: "Пока нет готового перевода", duration: 2)
            return
        }

        translationOverlayService.showPersistentLastTranslation(formattedText)
    }

    func refreshPermissionState() {
        let granted = permissionService.hasPermission
        showPermissionHelp = !granted
        if granted {
            statusMessage = "Готово к захвату."
        }
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }

    func deleteSelectedEntry() {
        guard let profileIndex = selectedProfileIndex, let selectedEntryID else { return }
        guard profiles[profileIndex].deleteEntry(with: selectedEntryID) else { return }
        self.selectedEntryID = profiles[profileIndex].selectedEntryID
        syncSelectionToEditor()
        persistHistory()
        statusMessage = "Перевод удален."
    }

    func createProfile(named rawName: String, learningLanguage: LearningLanguage) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Новый профиль" : trimmed
        let profile = LearningProfile(name: name, learningLanguage: learningLanguage)
        profiles.insert(profile, at: 0)
        setDefaultNewProfileLearningLanguage(learningLanguage)
        selectProfile(profile.id)
        persistHistory()
        statusMessage = "Профиль \"\(name)\" создан для языка \(learningLanguage.title.lowercased())."
    }

    func selectProfile(_ id: LearningProfile.ID?) {
        selectedProfileID = id
        syncProfileSelectionToEditor()
        if let activeProfile {
            statusMessage = "Выбрана история \"\(activeProfile.name)\" (\(activeProfile.learningLanguage.title.lowercased()))."
        }
    }

    func deleteSelectedProfile() {
        guard let currentProfileID = selectedProfileID,
              let profileIndex = profiles.firstIndex(where: { $0.id == currentProfileID }) else { return }
        guard !profiles[profileIndex].isDefaultProfile else {
            statusMessage = "Сессию Default удалить нельзя."
            return
        }
        let removedName = profiles[profileIndex].name
        profiles.remove(at: profileIndex)

        if let firstID = profiles.first?.id {
            selectedProfileID = firstID
        }

        syncProfileSelectionToEditor()
        persistHistory()
        statusMessage = "Профиль \"\(removedName)\" удален."
    }

    var canDeleteSelectedProfile: Bool {
        activeProfile?.isDefaultProfile == false
    }

    var history: [CapturedTextEntry] {
        guard let selectedProfileIndex else { return [] }
        return profiles[selectedProfileIndex].history
    }

    /// Переводы текущей сессии от первого по времени к последнему для режима «весь текст».
    var sessionReadingSequence: [SessionReadingSequenceItem] {
        guard let selectedProfileIndex else { return [] }
        let language = profiles[selectedProfileIndex].learningLanguage
        return profiles[selectedProfileIndex].history
            .sorted(by: { $0.createdAt < $1.createdAt })
            .map { entry in
                SessionReadingSequenceItem(
                    id: entry.id,
                    sourceLine: entry.sessionReadingSourceLine(learningLanguage: language),
                    translationLine: entry.sessionReadingTranslationLine()
                )
            }
    }

    /// Плоский текст режима «вся сессия» для буфера обмена: у каждого фрагмента две строки, блоки разделены пустой строкой.
    static func plainTextForSessionReadingCopy(items: [SessionReadingSequenceItem]) -> String {
        items
            .map { "\($0.displaySourceLine)\n\($0.displayTranslationLine)" }
            .joined(separator: "\n\n")
    }

    var sessionReadingOverviewPlainTextForCopy: String {
        Self.plainTextForSessionReadingCopy(items: sessionReadingSequence)
    }

    /// Копирует текст режима «вся сессия» в общий буфер обмена macOS.
    func copySessionReadingOverviewToPasteboard() {
        let text = sessionReadingOverviewPlainTextForCopy
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func toggleSessionReadingOverview() {
        showsSessionReadingOverview.toggle()
    }

    var selectedProfileName: String {
        activeProfile?.name ?? "Профиль"
    }

    var canDeleteSelectedEntry: Bool {
        selectedEntryIndex != nil
    }

    func selectEntry(_ id: CapturedTextEntry.ID?) {
        showsSessionReadingOverview = false
        selectedEntryID = id
        if let selectedProfileIndex {
            profiles[selectedProfileIndex].selectedEntryID = id
        }
        syncSelectionToEditor()
    }

    func updateSelectedText(_ newText: String) {
        recognizedText = newText
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return }
        profiles[profileIndex].history[entryIndex].text = newText
        profiles[profileIndex].history[entryIndex].formattedText = nil
        profiles[profileIndex].history[entryIndex].formattingStatus = .notRequested
        profiles[profileIndex].history[entryIndex].studyMaterials = StudyMaterials()
        formattedRecognizedText = nil
        studyMaterials = StudyMaterials()
        profiles[profileIndex].selectedEntryID = selectedEntryID
        persistHistory()
    }

    func retryFormattingForSelectedEntry() {
        guard let selectedEntryID else { return }
        Task {
            await formatEntryText(entryID: selectedEntryID, forceRetry: true)
        }
    }

    func formattedDate(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    func retryStudyAssistantDataForSelectedEntry() {
        guard let selectedEntryID else { return }
        Task {
            await loadStudyMaterial(for: selectedEntryID, forceReload: true)
        }
    }

    private func ensureScreenRecordingPermission() -> Bool {
        if permissionService.hasPermission {
            showPermissionHelp = false
            return true
        }

        showPermissionHelp = true
        statusMessage = "Нет доступа к Screen Recording. Откройте System Settings и включите доступ."
        return false
    }

    private var shouldUseCompactOverlay: Bool {
        !NSApp.isActive
    }

    private func startCaptureFlow(triggeredBy source: CaptureTriggerSource) async {
        guard !isProcessing else { return }
        guard ensureScreenRecordingPermission() else { return }

        isProcessing = true
        statusMessage = "Выберите область на экране..."

        defer {
            isProcessing = false
        }

        do {
            let selectedRect = try await regionSelectionService.selectRegion()
            statusMessage = "Снимаю выделенную область..."

            let image = try await screenshotService.capture(region: selectedRect)
            capturedImage = NSImage(cgImage: image, size: .zero)
            statusMessage = "Распознаю текст..."

            let text = try await recognizeText(in: image)
            guard !text.isEmpty else {
                recognizedText = ""
                statusMessage = "Текст не найден."
                overlayEntryAwaitingFormattedResult = nil
                if source == .hotkey, shouldUseCompactOverlay {
                    translationOverlayService.showMessage(title: "Текст не найден", duration: 3)
                }
                return
            }

            let imagePreview = NSImage(cgImage: image, size: .zero)
            let entry = CapturedTextEntry(text: text, image: imagePreview)
            guard let selectedProfileIndex else { return }
            profiles[selectedProfileIndex].history.insert(entry, at: 0)
            profiles[selectedProfileIndex].selectedEntryID = entry.id
            selectedEntryID = entry.id
            syncSelectionToEditor()
            persistHistory()
            statusMessage = "Готово. Запись добавлена в историю. Форматирую текст..."
            if source == .hotkey, shouldUseCompactOverlay {
                overlayEntryAwaitingFormattedResult = entry.id
                translationOverlayService.showLoading()
            }
            await formatEntryText(entryID: entry.id, forceRetry: false)
        } catch RegionSelectionService.SelectionError.cancelled {
            statusMessage = "Выделение отменено."
            overlayEntryAwaitingFormattedResult = nil
            if source == .hotkey, shouldUseCompactOverlay {
                translationOverlayService.hide()
            }
        } catch {
            statusMessage = "Ошибка: \(error.localizedDescription)"
            overlayEntryAwaitingFormattedResult = nil
            if source == .hotkey, shouldUseCompactOverlay {
                translationOverlayService.showMessage(title: "Ошибка обработки", subtitle: error.localizedDescription, duration: 3)
            }
        }
    }

    private func recognizeText(in image: CGImage) async throws -> String {
        switch selectedOCREngine {
        case .local:
            return try await ocrService.recognizeText(in: image)
        case .ai:
            guard let token = apiKeyRepository.loadAPIKey() else {
                throw OpenAIServiceError.invalidTokenFormat
            }
            guard let modelID = selectedOpenAIModelID else {
                throw OpenAIServiceError.invalidResponse
            }
            return try await openAIService.recognizeTextInImage(
                apiKey: token,
                modelID: modelID,
                image: image
            )
        }
    }

    private var selectedEntryIndex: Int? {
        guard let selectedEntryID else { return nil }
        guard let selectedProfileIndex else { return nil }
        return profiles[selectedProfileIndex].history.firstIndex(where: { $0.id == selectedEntryID })
    }

    private var selectedProfileIndex: Int? {
        guard let selectedProfileID else { return nil }
        return profiles.firstIndex(where: { $0.id == selectedProfileID })
    }

    private var activeProfile: LearningProfile? {
        guard let selectedProfileIndex else { return nil }
        return profiles[selectedProfileIndex]
    }

    private func syncSelectionToEditor() {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else {
            recognizedText = ""
            formattedRecognizedText = nil
            studyMaterials = StudyMaterials()
            capturedImage = nil
            return
        }
        recognizedText = profiles[profileIndex].history[entryIndex].text
        formattedRecognizedText = profiles[profileIndex].history[entryIndex].formattedText
        studyMaterials = profiles[profileIndex].history[entryIndex].studyMaterials
        capturedImage = profiles[profileIndex].history[entryIndex].image
    }

    private func syncProfileSelectionToEditor() {
        showsSessionReadingOverview = false
        guard let selectedProfileIndex else {
            selectedEntryID = nil
            recognizedText = ""
            formattedRecognizedText = nil
            studyMaterials = StudyMaterials()
            capturedImage = nil
            return
        }

        if let persistedSelection = profiles[selectedProfileIndex].selectedEntryID,
           profiles[selectedProfileIndex].history.contains(where: { $0.id == persistedSelection }) {
            selectedEntryID = persistedSelection
        } else {
            selectedEntryID = profiles[selectedProfileIndex].history.first?.id
            profiles[selectedProfileIndex].selectedEntryID = selectedEntryID
        }
        syncSelectionToEditor()
    }

    private func loadHistory() {
        do {
            var store = try historyRepository.loadStore()
            store.profiles = store.profiles.map(HistoryEntryLoadRepair.repairProfile)
            if !store.profiles.contains(where: \.isDefaultProfile) {
                store.profiles.insert(.defaultProfile(), at: 0)
            }
            if let defaultIndex = store.profiles.firstIndex(where: \.isDefaultProfile), defaultIndex != 0 {
                let defaultProfile = store.profiles.remove(at: defaultIndex)
                store.profiles.insert(defaultProfile, at: 0)
            }
            profiles = store.profiles
            selectedProfileID = store.selectedProfileID
            if selectedProfileIndex == nil {
                selectedProfileID = profiles.first?.id
            }
            syncProfileSelectionToEditor()
        } catch {
            statusMessage = "Не удалось загрузить историю: \(error.localizedDescription)"
        }
    }

    private func persistHistory() {
        do {
            let store = HistoryStoreSnapshot(profiles: profiles, selectedProfileID: selectedProfileID)
            try historyRepository.saveStore(store)
        } catch {
            statusMessage = "Не удалось сохранить историю: \(error.localizedDescription)"
        }
    }

    private func formatEntryText(entryID: CapturedTextEntry.ID, forceRetry: Bool) async {
        guard !isFormattingRecognizedText else { return }
        guard let token = apiKeyRepository.loadAPIKey() else {
            statusMessage = "Сначала сохраните OpenAI token."
            if overlayEntryAwaitingFormattedResult == entryID {
                translationOverlayService.showMessage(title: "Сначала сохраните OpenAI token", duration: 3)
                overlayEntryAwaitingFormattedResult = nil
            }
            return
        }
        guard let modelID = selectedOpenAIModelID else {
            statusMessage = "Выберите модель OpenAI."
            if overlayEntryAwaitingFormattedResult == entryID {
                translationOverlayService.showMessage(title: "Выберите модель OpenAI", duration: 3)
                overlayEntryAwaitingFormattedResult = nil
            }
            return
        }
        guard let profileIndex = selectedProfileIndex else { return }
        guard let entryIndex = profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else { return }

        let currentStatus = profiles[profileIndex].history[entryIndex].formattingStatus
        let currentFormattedText = profiles[profileIndex].history[entryIndex].formattedText
        if !forceRetry, currentStatus == .succeeded, currentFormattedText?.hasContent == true {
            return
        }
        if !forceRetry, currentStatus == .processing {
            return
        }

        let rawText = profiles[profileIndex].history[entryIndex].text
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isFormattingRecognizedText = true
        profiles[profileIndex].history[entryIndex].formattingStatus = .processing
        persistHistory()

        defer {
            isFormattingRecognizedText = false
        }

        do {
            let formatted = try await openAIService.formatRecognizedText(
                apiKey: token,
                modelID: modelID,
                targetLanguage: profiles[profileIndex].learningLanguage,
                rawText: rawText
            )

            guard let latestProfileIndex = selectedProfileIndex,
                  let latestEntryIndex = profiles[latestProfileIndex].history.firstIndex(where: { $0.id == entryID }) else {
                return
            }

            profiles[latestProfileIndex].history[latestEntryIndex].formattedText = formatted
            profiles[latestProfileIndex].history[latestEntryIndex].formattingStatus = .succeeded
            if selectedEntryID == entryID {
                formattedRecognizedText = formatted
            }
            persistHistory()
            statusMessage = "Форматирование завершено."
            if overlayEntryAwaitingFormattedResult == entryID {
                if shouldUseCompactOverlay {
                    translationOverlayService.showTranslation(
                        formatted,
                        duration: calculatedTranslationOverlayDuration(for: formatted)
                    )
                } else {
                    translationOverlayService.hide()
                }
                overlayEntryAwaitingFormattedResult = nil
            }
        } catch {
            guard let latestProfileIndex = selectedProfileIndex,
                  let latestEntryIndex = profiles[latestProfileIndex].history.firstIndex(where: { $0.id == entryID }) else {
                return
            }
            profiles[latestProfileIndex].history[latestEntryIndex].formattedText = nil
            profiles[latestProfileIndex].history[latestEntryIndex].formattingStatus = .failed
            if selectedEntryID == entryID {
                formattedRecognizedText = nil
            }
            persistHistory()
            statusMessage = "Не удалось отформатировать текст: \(error.localizedDescription)"
            if overlayEntryAwaitingFormattedResult == entryID {
                if shouldUseCompactOverlay {
                    translationOverlayService.showMessage(
                        title: "Не удалось получить перевод",
                        subtitle: error.localizedDescription,
                        duration: 3
                    )
                } else {
                    translationOverlayService.hide()
                }
                overlayEntryAwaitingFormattedResult = nil
            }
        }
    }

    private func loadStudyMaterial(for entryID: CapturedTextEntry.ID, forceReload: Bool) async {
        guard currentProfileSupportsWordStudy else { return }
        guard let token = apiKeyRepository.loadAPIKey() else {
            statusMessage = "Сначала сохраните OpenAI token."
            return
        }
        guard let modelID = selectedOpenAIModelID else {
            statusMessage = "Выберите модель OpenAI."
            return
        }
        guard let profileIndex = selectedProfileIndex,
              let entryIndex = profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        var entry = profiles[profileIndex].history[entryIndex]
        guard let formattedText = entry.formattedText, formattedText.hasContent else { return }
        if !forceReload, entry.studyMaterials.wordsStatus == .succeeded, entry.studyMaterials.words?.hasContent == true { return }
        if !forceReload, entry.studyMaterials.wordsStatus == .processing { return }
        profiles[profileIndex].history[entryIndex].studyMaterials.wordsStatus = .processing
        persistHistory()
        entry = profiles[profileIndex].history[entryIndex]

        do {
            let result = try await openAIService.buildWordsStudyData(
                apiKey: token,
                modelID: modelID,
                targetLanguage: profiles[profileIndex].learningLanguage,
                formattedText: formattedText
            )
            guard let latestProfileIndex = selectedProfileIndex,
                  let latestEntryIndex = profiles[latestProfileIndex].history.firstIndex(where: { $0.id == entryID }) else { return }
            profiles[latestProfileIndex].history[latestEntryIndex].studyMaterials.words = result
            profiles[latestProfileIndex].history[latestEntryIndex].studyMaterials.wordsStatus = .succeeded

            if selectedEntryID == entryID {
                studyMaterials = profiles[selectedProfileIndex!].history[profiles[selectedProfileIndex!].history.firstIndex(where: { $0.id == entryID })!].studyMaterials
            }
            persistHistory()
            statusMessage = "Перевод слов готов."
        } catch {
            guard let latestProfileIndex = selectedProfileIndex,
                  let latestEntryIndex = profiles[latestProfileIndex].history.firstIndex(where: { $0.id == entryID }) else {
                return
            }
            profiles[latestProfileIndex].history[latestEntryIndex].studyMaterials.words = nil
            profiles[latestProfileIndex].history[latestEntryIndex].studyMaterials.wordsStatus = .failed
            if selectedEntryID == entryID {
                studyMaterials = profiles[latestProfileIndex].history[latestEntryIndex].studyMaterials
            }
            persistHistory()
            statusMessage = "Не удалось получить перевод слов: \(error.localizedDescription)"
        }
    }

    var canRetryFormatting: Bool {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return false }
        let entry = profiles[profileIndex].history[entryIndex]
        return entry.formattingStatus == .failed && (entry.formattedText?.hasContent ?? false) == false
    }

    var selectedEntryFormattingStatus: FormattingStatus? {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return nil }
        return profiles[profileIndex].history[entryIndex].formattingStatus
    }

    var selectedEntryStudyAssistantStatus: FormattingStatus? {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return nil }
        return profiles[profileIndex].history[entryIndex].studyMaterials.wordsStatus
    }

    var canRetryStudyAssistantData: Bool {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return false }
        let materials = profiles[profileIndex].history[entryIndex].studyMaterials
        return materials.wordsStatus == .failed && (materials.words?.hasContent ?? false) == false
    }
}

