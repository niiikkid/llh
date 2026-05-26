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
    @Published private(set) var isFormattingRecognizedText = false
    @Published private(set) var showsSessionReadingOverview = false

    private let permissionService: ScreenRecordingPermissionChecking
    private let captureRegionUseCase: CaptureRegionUseCase
    private let formatCapturedTextUseCase: FormatCapturedTextUseCase
    private let manageHistoryUseCase: ManageHistoryUseCase
    private let manageProfilesUseCase: ManageProfilesUseCase
    private let loadWordStudyUseCase: LoadWordStudyUseCase
    let settings: SettingsViewModel
    private let translationOverlayService: TranslationOverlayService
    private var overlayEntryAwaitingFormattedResult: CapturedTextEntry.ID?
    private var cancellables = Set<AnyCancellable>()

    init(dependencies: AppDependencyContainer) {
        permissionService = dependencies.permissionService
        captureRegionUseCase = dependencies.captureRegionUseCase
        formatCapturedTextUseCase = dependencies.formatCapturedTextUseCase
        manageHistoryUseCase = dependencies.manageHistoryUseCase
        manageProfilesUseCase = dependencies.manageProfilesUseCase
        loadWordStudyUseCase = dependencies.loadWordStudyUseCase
        translationOverlayService = dependencies.translationOverlayService
        settings = SettingsViewModel(
            manageOpenAISettingsUseCase: dependencies.manageOpenAISettingsUseCase,
            translationOverlayService: dependencies.translationOverlayService
        )
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [weak self] in
            Task { @MainActor [weak self] in
                self?.closeTranslationOverlay()
                await self?.startCaptureFlow(triggeredBy: .hotkey)
            }
        }
        KeyboardShortcuts.onKeyUp(for: .switchOCREngine) { [weak self] in
            Task { @MainActor [weak self] in
                self?.closeTranslationOverlay(cancelPendingResult: false)
                self?.settings.switchToNextOCREngine(triggeredByHotkey: true)
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
        settings.configureStatusReporting { [weak self] message in
            self?.statusMessage = message
        }
        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        loadHistory()
        refreshPermissionState()
    }

    var currentProfileLearningLanguage: LearningLanguage {
        activeProfile?.learningLanguage ?? settings.defaultNewProfileLearningLanguage
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
        guard let selectedEntryID else { return }
        var session = historySession
        guard manageHistoryUseCase.deleteEntry(state: &session, entryID: selectedEntryID) else { return }
        applyHistorySession(session)
        syncSelectionToEditor()
        persistHistory()
        statusMessage = "Перевод удален."
    }

    func createProfile(named rawName: String, learningLanguage: LearningLanguage) {
        var session = historySession
        let profile = manageProfilesUseCase.createProfile(
            state: &session,
            named: rawName,
            learningLanguage: learningLanguage
        )
        settings.setDefaultNewProfileLearningLanguage(learningLanguage)
        applyHistorySession(session)
        syncSelectionToEditor()
        persistHistory()
        statusMessage = "Профиль \"\(profile.name)\" создан для языка \(learningLanguage.title.lowercased())."
    }

    func selectProfile(_ id: LearningProfile.ID?) {
        showsSessionReadingOverview = false
        var session = historySession
        manageProfilesUseCase.selectProfile(state: &session, profileID: id)
        applyHistorySession(session)
        syncSelectionToEditor()
        if let activeProfile {
            statusMessage = "Выбрана история \"\(activeProfile.name)\" (\(activeProfile.learningLanguage.title.lowercased()))."
        } else {
            recognizedText = ""
            formattedRecognizedText = nil
            studyMaterials = StudyMaterials()
            capturedImage = nil
        }
    }

    func deleteSelectedProfile() {
        var session = historySession
        switch manageProfilesUseCase.deleteSelectedProfile(state: &session) {
        case .deleted(let removedName):
            applyHistorySession(session)
            syncSelectionToEditor()
            persistHistory()
            statusMessage = "Профиль \"\(removedName)\" удален."
        case .cannotDeleteDefaultProfile:
            statusMessage = "Сессию Default удалить нельзя."
        case .noSelectedProfile:
            break
        }
    }

    var canDeleteSelectedProfile: Bool {
        manageProfilesUseCase.canDeleteSelectedProfile(state: historySession)
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
        var session = historySession
        manageHistoryUseCase.selectEntry(state: &session, entryID: id)
        applyHistorySession(session)
        syncSelectionToEditor()
    }

    func updateSelectedText(_ newText: String) {
        recognizedText = newText
        var session = historySession
        guard manageHistoryUseCase.updateSelectedEntryText(state: &session, newText: newText) else { return }
        applyHistorySession(session)
        formattedRecognizedText = nil
        studyMaterials = StudyMaterials()
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

    private var shouldUseCompactOverlay: Bool {
        !NSApp.isActive
    }

    private func startCaptureFlow(triggeredBy source: CaptureTriggerSource) async {
        guard !isProcessing else { return }

        isProcessing = true
        statusMessage = "Выберите область на экране..."

        defer {
            isProcessing = false
        }

        let configuration = CaptureRegionConfiguration(
            ocrEngine: settings.selectedOCREngine,
            apiKey: settings.currentAPIKey(),
            selectedModelID: settings.selectedOpenAIModelID
        )

        do {
            switch try await captureRegionUseCase.execute(configuration: configuration) {
            case .permissionDenied:
                showPermissionHelp = true
                statusMessage = "Нет доступа к Screen Recording. Откройте System Settings и включите доступ."
            case .selectionCancelled:
                showPermissionHelp = false
                statusMessage = "Выделение отменено."
                overlayEntryAwaitingFormattedResult = nil
                if source == .hotkey, shouldUseCompactOverlay {
                    translationOverlayService.hide()
                }
            case .noTextFound(let image):
                showPermissionHelp = false
                capturedImage = NSImage(cgImage: image, size: .zero)
                recognizedText = ""
                statusMessage = "Текст не найден."
                overlayEntryAwaitingFormattedResult = nil
                if source == .hotkey, shouldUseCompactOverlay {
                    translationOverlayService.showMessage(title: "Текст не найден", duration: 3)
                }
            case .captured(let image, let text):
                showPermissionHelp = false
                capturedImage = NSImage(cgImage: image, size: .zero)
                let imagePreview = NSImage(cgImage: image, size: .zero)
                let entry = CapturedTextEntry(text: text, image: imagePreview)
                guard let selectedProfileIndex else { return }
                var session = historySession
                manageHistoryUseCase.insertEntry(
                    state: &session,
                    profileIndex: selectedProfileIndex,
                    entry: entry
                )
                applyHistorySession(session)
                syncSelectionToEditor()
                persistHistory()
                statusMessage = "Готово. Запись добавлена в историю. Форматирую текст..."
                if source == .hotkey, shouldUseCompactOverlay {
                    overlayEntryAwaitingFormattedResult = entry.id
                    translationOverlayService.showLoading()
                }
                await formatEntryText(entryID: entry.id, forceRetry: false)
            }
        } catch {
            showPermissionHelp = false
            statusMessage = "Ошибка: \(error.localizedDescription)"
            overlayEntryAwaitingFormattedResult = nil
            if source == .hotkey, shouldUseCompactOverlay {
                translationOverlayService.showMessage(
                    title: "Ошибка обработки",
                    subtitle: error.localizedDescription,
                    duration: 3
                )
            }
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

    private func loadHistory() {
        do {
            var session = try manageHistoryUseCase.loadSession()
            manageHistoryUseCase.resolveEntrySelectionForSelectedProfile(state: &session)
            applyHistorySession(session)
            syncSelectionToEditor()
        } catch {
            statusMessage = "Не удалось загрузить историю: \(error.localizedDescription)"
        }
    }

    private func persistHistory() {
        do {
            try manageHistoryUseCase.saveSession(historySession)
        } catch {
            statusMessage = "Не удалось сохранить историю: \(error.localizedDescription)"
        }
    }

    private var historySession: HistorySessionState {
        HistorySessionState(
            profiles: profiles,
            selectedProfileID: selectedProfileID,
            selectedEntryID: selectedEntryID
        )
    }

    private func applyHistorySession(_ session: HistorySessionState) {
        profiles = session.profiles
        selectedProfileID = session.selectedProfileID
        selectedEntryID = session.selectedEntryID
    }

    @discardableResult
    private func mutateHistoryEntry(
        profileID: LearningProfile.ID,
        entryID: CapturedTextEntry.ID,
        _ body: (inout CapturedTextEntry) -> Void
    ) -> Bool {
        var session = historySession
        guard manageHistoryUseCase.mutateEntry(
            state: &session,
            profileID: profileID,
            entryID: entryID,
            body
        ) else {
            return false
        }
        applyHistorySession(session)
        return true
    }

    private func formatEntryText(entryID: CapturedTextEntry.ID, forceRetry: Bool) async {
        guard !isFormattingRecognizedText else { return }
        guard let profileIndex = selectedProfileIndex else { return }
        guard let entryIndex = profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else { return }

        let entry = profiles[profileIndex].history[entryIndex]
        let request = FormatCapturedTextRequest(
            rawText: entry.text,
            targetLanguage: profiles[profileIndex].learningLanguage,
            forceRetry: forceRetry,
            currentStatus: entry.formattingStatus,
            currentFormattedText: entry.formattedText
        )

        let configuration = FormatCapturedTextConfiguration(
            apiKey: settings.currentAPIKey(),
            modelID: settings.selectedOpenAIModelID
        )

        switch formatCapturedTextUseCase.preflight(request: request, configuration: configuration) {
        case .missingAPIKey:
            statusMessage = "Сначала сохраните OpenAI token."
            clearOverlayAwaitingFormat(entryID: entryID, title: "Сначала сохраните OpenAI token")
            return
        case .missingModel:
            statusMessage = "Выберите модель OpenAI."
            clearOverlayAwaitingFormat(entryID: entryID, title: "Выберите модель OpenAI")
            return
        case .skipped:
            return
        case .ready:
            break
        }

        guard beginFormattingEntry(entryID: entryID) else { return }
        defer { endFormattingEntry() }

        do {
            let formatted = try await formatCapturedTextUseCase.perform(
                request: request,
                configuration: configuration
            )
            applyFormattingSuccess(entryID: entryID, formatted: formatted)
        } catch {
            applyFormattingFailure(entryID: entryID, error: error)
        }
    }

    private func applyFormattingSuccess(entryID: CapturedTextEntry.ID, formatted: StructuredFormattedText) {
        guard let profileID = selectedProfileID else { return }
        guard mutateHistoryEntry(profileID: profileID, entryID: entryID, { entry in
            entry.formattedText = formatted
            entry.formattingStatus = .succeeded
        }) else {
            return
        }

        if selectedEntryID == entryID {
            formattedRecognizedText = formatted
        }
        persistHistory()
        statusMessage = "Форматирование завершено."
        if overlayEntryAwaitingFormattedResult == entryID {
            if shouldUseCompactOverlay {
                translationOverlayService.showTranslation(
                    formatted,
                    duration: settings.calculatedTranslationOverlayDuration(for: formatted)
                )
            } else {
                translationOverlayService.hide()
            }
            overlayEntryAwaitingFormattedResult = nil
        }
    }

    private func applyFormattingFailure(entryID: CapturedTextEntry.ID, error: Error) {
        guard let profileID = selectedProfileID else { return }
        guard mutateHistoryEntry(profileID: profileID, entryID: entryID, { entry in
            entry.formattedText = nil
            entry.formattingStatus = .failed
        }) else {
            return
        }

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

    private func clearOverlayAwaitingFormat(entryID: CapturedTextEntry.ID, title: String) {
        guard overlayEntryAwaitingFormattedResult == entryID else { return }
        translationOverlayService.showMessage(title: title, duration: 3)
        overlayEntryAwaitingFormattedResult = nil
    }

    private func beginFormattingEntry(entryID: CapturedTextEntry.ID) -> Bool {
        guard let profileID = selectedProfileID else { return false }
        isFormattingRecognizedText = true
        guard mutateHistoryEntry(profileID: profileID, entryID: entryID, { entry in
            entry.formattingStatus = .processing
        }) else {
            isFormattingRecognizedText = false
            return false
        }
        persistHistory()
        return true
    }

    private func endFormattingEntry() {
        isFormattingRecognizedText = false
    }

    private func loadStudyMaterial(for entryID: CapturedTextEntry.ID, forceReload: Bool) async {
        guard let profileIndex = selectedProfileIndex,
              let entryIndex = profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        let entry = profiles[profileIndex].history[entryIndex]
        let request = LoadWordStudyRequest(
            targetLanguage: profiles[profileIndex].learningLanguage,
            profileSupportsWordStudy: currentProfileSupportsWordStudy,
            forceReload: forceReload,
            formattedText: entry.formattedText,
            wordsStatus: entry.studyMaterials.wordsStatus,
            words: entry.studyMaterials.words
        )
        let configuration = LoadWordStudyConfiguration(
            apiKey: settings.currentAPIKey(),
            modelID: settings.selectedOpenAIModelID
        )

        switch loadWordStudyUseCase.preflight(request: request, configuration: configuration) {
        case .missingAPIKey:
            statusMessage = "Сначала сохраните OpenAI token."
            return
        case .missingModel:
            statusMessage = "Выберите модель OpenAI."
            return
        case .skipped:
            return
        case .ready:
            break
        }

        let activeProfileID = profiles[profileIndex].id
        guard mutateHistoryEntry(profileID: activeProfileID, entryID: entryID, { entry in
            entry.studyMaterials.wordsStatus = .processing
        }) else {
            return
        }
        persistHistory()

        do {
            let result = try await loadWordStudyUseCase.perform(
                request: request,
                configuration: configuration
            )
            applyWordStudySuccess(entryID: entryID, profileID: activeProfileID, payload: result)
        } catch {
            applyWordStudyFailure(entryID: entryID, profileID: activeProfileID, error: error)
        }
    }

    private func applyWordStudySuccess(
        entryID: CapturedTextEntry.ID,
        profileID: LearningProfile.ID,
        payload: WordStudyPayload
    ) {
        guard mutateHistoryEntry(profileID: profileID, entryID: entryID, { entry in
            entry.studyMaterials.words = payload
            entry.studyMaterials.wordsStatus = .succeeded
        }) else {
            return
        }
        syncStudyMaterialsToEditorIfSelected(entryID: entryID)
        persistHistory()
        statusMessage = "Перевод слов готов."
    }

    private func applyWordStudyFailure(
        entryID: CapturedTextEntry.ID,
        profileID: LearningProfile.ID,
        error: Error
    ) {
        guard mutateHistoryEntry(profileID: profileID, entryID: entryID, { entry in
            entry.studyMaterials.words = nil
            entry.studyMaterials.wordsStatus = .failed
        }) else {
            return
        }
        syncStudyMaterialsToEditorIfSelected(entryID: entryID)
        persistHistory()
        statusMessage = "Не удалось получить перевод слов: \(error.localizedDescription)"
    }

    private func syncStudyMaterialsToEditorIfSelected(entryID: CapturedTextEntry.ID) {
        guard selectedEntryID == entryID,
              let currentProfileIndex = selectedProfileIndex,
              let currentEntryIndex = profiles[currentProfileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return
        }
        studyMaterials = profiles[currentProfileIndex].history[currentEntryIndex].studyMaterials
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

