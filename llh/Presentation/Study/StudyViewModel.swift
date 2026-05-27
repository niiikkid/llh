//
//  StudyViewModel.swift
//  llh
//

import Combine
import Foundation

@MainActor
final class StudyViewModel: ObservableObject {
    @Published var selectedLearningTab: StudyLearningTab = .words
    @Published private(set) var studyMaterials = StudyMaterials()
    @Published private(set) var statusMessage = ""

    private let loadWordStudyUseCase: LoadWordStudyUseCase
    private let loadGrammarStudyUseCase: LoadGrammarStudyUseCase
    private let settings: SettingsViewModel
    private let history: HistoryViewModel

    init(
        loadWordStudyUseCase: LoadWordStudyUseCase,
        loadGrammarStudyUseCase: LoadGrammarStudyUseCase,
        settings: SettingsViewModel,
        history: HistoryViewModel
    ) {
        self.loadWordStudyUseCase = loadWordStudyUseCase
        self.loadGrammarStudyUseCase = loadGrammarStudyUseCase
        self.settings = settings
        self.history = history
    }

    func applyStudyMaterialsFromEntry(_ materials: StudyMaterials) {
        studyMaterials = materials
    }

    func clearStudyMaterials() {
        studyMaterials = StudyMaterials()
    }

    func retryStudyAssistantDataForSelectedEntry() {
        guard let selectedEntryID = history.selectedEntryID else { return }
        Task {
            switch selectedLearningTab {
            case .words:
                await loadWordStudy(for: selectedEntryID, forceReload: true)
            case .grammar:
                await loadGrammarStudy(for: selectedEntryID, forceReload: true)
            }
        }
    }

    func startSessionAutomationAfterFormattingSuccess(
        profileID: LearningProfile.ID,
        entryID: CapturedTextEntry.ID
    ) {
        guard let profileIndex = history.profiles.firstIndex(where: { $0.id == profileID }) else {
            return
        }
        let profile = history.profiles[profileIndex]
        if profile.automaticallyLoadWords {
            Task {
                await loadWordStudy(for: entryID, forceReload: false)
            }
        }
        if profile.automaticallyLoadGrammar {
            Task {
                await loadGrammarStudy(for: entryID, forceReload: false)
            }
        }
    }

    var selectedEntryWordsStatus: FormattingStatus? {
        selectedEntryMaterials?.wordsStatus
    }

    var selectedEntryGrammarStatus: FormattingStatus? {
        selectedEntryMaterials?.grammarStatus
    }

    var activeLearningTabStatus: FormattingStatus? {
        switch selectedLearningTab {
        case .words: selectedEntryWordsStatus
        case .grammar: selectedEntryGrammarStatus
        }
    }

    var hasWordsContent: Bool {
        studyMaterials.words?.hasContent == true
    }

    var hasGrammarContent: Bool {
        studyMaterials.grammar?.hasContent == true
    }

    var hasActiveTabContent: Bool {
        switch selectedLearningTab {
        case .words:
            hasWordsContent && selectedEntryWordsStatus != .processing
        case .grammar:
            hasGrammarContent && selectedEntryGrammarStatus != .processing
        }
    }

    var canRetryWordsStudy: Bool {
        guard let materials = selectedEntryMaterials else { return false }
        return materials.wordsStatus == .failed && (materials.words?.hasContent ?? false) == false
    }

    var canRetryGrammarStudy: Bool {
        guard let materials = selectedEntryMaterials else { return false }
        return materials.grammarStatus == .failed && (materials.grammar?.hasContent ?? false) == false
    }

    var canRetryActiveLearningTab: Bool {
        switch selectedLearningTab {
        case .words: canRetryWordsStudy
        case .grammar: canRetryGrammarStudy
        }
    }

    var sessionAutomaticallyLoadsWords: Bool {
        activeProfile?.automaticallyLoadWords == true
    }

    var sessionAutomaticallyLoadsGrammar: Bool {
        activeProfile?.automaticallyLoadGrammar == true
    }

    private var activeProfile: LearningProfile? {
        guard let profileIndex = history.selectedProfileIndex else { return nil }
        return history.profiles[profileIndex]
    }

    var activeTabRetryButtonTitle: String {
        switch selectedLearningTab {
        case .words:
            hasWordsContent ? "Обновить перевод" : "Перевести слова"
        case .grammar:
            hasGrammarContent ? "Обновить грамматику" : "Объяснить грамматику"
        }
    }

    private var selectedEntryMaterials: StudyMaterials? {
        guard let profileIndex = history.selectedProfileIndex,
              let entryIndex = history.selectedEntryIndex else { return nil }
        return history.profiles[profileIndex].history[entryIndex].studyMaterials
    }

    private func loadWordStudy(for entryID: CapturedTextEntry.ID, forceReload: Bool) async {
        guard let profileIndex = history.selectedProfileIndex,
              let entryIndex = history.profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        let entry = history.profiles[profileIndex].history[entryIndex]
        let request = LoadWordStudyRequest(
            targetLanguage: history.profiles[profileIndex].learningLanguage,
            profileSupportsWordStudy: history.currentProfileSupportsWordStudy,
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
            publishStatus("Сначала сохраните OpenAI token.")
            return
        case .missingModel:
            publishStatus("Выберите модель OpenAI.")
            return
        case .skipped:
            return
        case .ready:
            break
        }

        let activeProfileID = history.profiles[profileIndex].id
        guard history.mutateEntry(profileID: activeProfileID, entryID: entryID, { entry in
            entry.studyMaterials.wordsStatus = .processing
        }) else {
            return
        }
        syncStudyMaterialsToEditorIfSelected(entryID: entryID)
        history.persist()

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

    private func loadGrammarStudy(for entryID: CapturedTextEntry.ID, forceReload: Bool) async {
        guard let profileIndex = history.selectedProfileIndex,
              let entryIndex = history.profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        let entry = history.profiles[profileIndex].history[entryIndex]
        let request = LoadGrammarStudyRequest(
            targetLanguage: history.profiles[profileIndex].learningLanguage,
            profileSupportsWordStudy: history.currentProfileSupportsWordStudy,
            forceReload: forceReload,
            formattedText: entry.formattedText,
            grammarStatus: entry.studyMaterials.grammarStatus,
            grammar: entry.studyMaterials.grammar
        )
        let configuration = LoadGrammarStudyConfiguration(
            apiKey: settings.currentAPIKey(),
            modelID: settings.selectedOpenAIModelID
        )

        switch loadGrammarStudyUseCase.preflight(request: request, configuration: configuration) {
        case .missingAPIKey:
            publishStatus("Сначала сохраните OpenAI token.")
            return
        case .missingModel:
            publishStatus("Выберите модель OpenAI.")
            return
        case .skipped:
            return
        case .ready:
            break
        }

        let activeProfileID = history.profiles[profileIndex].id
        guard history.mutateEntry(profileID: activeProfileID, entryID: entryID, { entry in
            entry.studyMaterials.grammarStatus = .processing
        }) else {
            return
        }
        syncStudyMaterialsToEditorIfSelected(entryID: entryID)
        history.persist()

        do {
            let result = try await loadGrammarStudyUseCase.perform(
                request: request,
                configuration: configuration
            )
            applyGrammarStudySuccess(entryID: entryID, profileID: activeProfileID, payload: result)
        } catch {
            applyGrammarStudyFailure(entryID: entryID, profileID: activeProfileID, error: error)
        }
    }

    private func applyWordStudySuccess(
        entryID: CapturedTextEntry.ID,
        profileID: LearningProfile.ID,
        payload: WordStudyPayload
    ) {
        guard history.mutateEntry(profileID: profileID, entryID: entryID, { entry in
            entry.studyMaterials.words = payload
            entry.studyMaterials.wordsStatus = .succeeded
        }) else {
            return
        }
        syncStudyMaterialsToEditorIfSelected(entryID: entryID)
        history.persist()
        publishStatus("Перевод слов готов.")
    }

    private func applyWordStudyFailure(
        entryID: CapturedTextEntry.ID,
        profileID: LearningProfile.ID,
        error: Error
    ) {
        guard history.mutateEntry(profileID: profileID, entryID: entryID, { entry in
            entry.studyMaterials.words = nil
            entry.studyMaterials.wordsStatus = .failed
        }) else {
            return
        }
        syncStudyMaterialsToEditorIfSelected(entryID: entryID)
        history.persist()
        publishStatus("Не удалось получить перевод слов: \(error.localizedDescription)")
    }

    private func applyGrammarStudySuccess(
        entryID: CapturedTextEntry.ID,
        profileID: LearningProfile.ID,
        payload: GrammarExplanationPayload
    ) {
        guard history.mutateEntry(profileID: profileID, entryID: entryID, { entry in
            entry.studyMaterials.grammar = payload
            entry.studyMaterials.grammarStatus = .succeeded
        }) else {
            return
        }
        syncStudyMaterialsToEditorIfSelected(entryID: entryID)
        history.persist()
        publishStatus("Грамматика готова.")
    }

    private func applyGrammarStudyFailure(
        entryID: CapturedTextEntry.ID,
        profileID: LearningProfile.ID,
        error: Error
    ) {
        guard history.mutateEntry(profileID: profileID, entryID: entryID, { entry in
            entry.studyMaterials.grammar = nil
            entry.studyMaterials.grammarStatus = .failed
        }) else {
            return
        }
        syncStudyMaterialsToEditorIfSelected(entryID: entryID)
        history.persist()
        publishStatus("Не удалось получить грамматику: \(error.localizedDescription)")
    }

    private func syncStudyMaterialsToEditorIfSelected(entryID: CapturedTextEntry.ID) {
        guard history.selectedEntryID == entryID,
              let profileIndex = history.selectedProfileIndex,
              let entryIndex = history.profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return
        }
        studyMaterials = history.profiles[profileIndex].history[entryIndex].studyMaterials
    }

    private func publishStatus(_ message: String) {
        statusMessage = message
    }
}
