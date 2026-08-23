//
//  StudyViewModel.swift
//  llh
//

import Combine
import Foundation

@MainActor
final class StudyViewModel: ObservableObject {
    @Published private(set) var studyMaterials = StudyMaterials()
    @Published private(set) var statusMessage = ""

    private let loadWordStudyUseCase: LoadWordStudyUseCase
    private let settings: SettingsViewModel
    private let history: HistoryViewModel
    private weak var overlayCoordinator: TranslationOverlayCoordinator?

    init(
        loadWordStudyUseCase: LoadWordStudyUseCase,
        settings: SettingsViewModel,
        history: HistoryViewModel,
        overlayCoordinator: TranslationOverlayCoordinator
    ) {
        self.loadWordStudyUseCase = loadWordStudyUseCase
        self.settings = settings
        self.history = history
        self.overlayCoordinator = overlayCoordinator
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
            await loadWordStudy(for: selectedEntryID, forceReload: true)
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
        if profile.automaticallyLoadWords || profile.showWordsInCompactOverlay {
            Task {
                await loadWordStudy(for: entryID, forceReload: false)
            }
        }
    }

    var selectedEntryWordsStatus: FormattingStatus? {
        selectedEntryMaterials?.wordsStatus
    }

    var hasWordsContent: Bool {
        studyMaterials.words?.hasContent == true
    }

    var hasVisibleWordsContent: Bool {
        hasWordsContent && selectedEntryWordsStatus != .processing
    }

    var canRetryWordsStudy: Bool {
        guard let materials = selectedEntryMaterials else { return false }
        return materials.wordsStatus == .failed && (materials.words?.hasContent ?? false) == false
    }

    var sessionAutomaticallyLoadsWords: Bool {
        activeProfile?.automaticallyLoadWords == true
    }

    private var activeProfile: LearningProfile? {
        guard let profileIndex = history.selectedProfileIndex else { return nil }
        return history.profiles[profileIndex]
    }

    var wordsRetryButtonTitle: String {
        hasWordsContent ? "Обновить перевод" : "Перевести слова"
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
            provider: settings.selectedTextProvider,
            apiKey: settings.textAPIKey(),
            modelID: settings.textModelID()
        )

        switch loadWordStudyUseCase.preflight(request: request, configuration: configuration) {
        case .missingAPIKey:
            publishStatus("Сначала сохраните token \(settings.selectedTextProvider.title).")
            return
        case .missingModel:
            publishStatus("Выберите модель \(settings.selectedTextProvider.title).")
            return
        case .skipped:
            overlayCoordinator?.refreshOverlayWordStudy(
                profileID: history.profiles[profileIndex].id,
                entryID: entryID
            )
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
        overlayCoordinator?.refreshOverlayWordStudy(profileID: activeProfileID, entryID: entryID)

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
        guard history.mutateEntry(profileID: profileID, entryID: entryID, { entry in
            entry.studyMaterials.words = payload
            entry.studyMaterials.wordsStatus = .succeeded
        }) else {
            return
        }
        syncStudyMaterialsToEditorIfSelected(entryID: entryID)
        history.persist()
        overlayCoordinator?.refreshOverlayWordStudy(profileID: profileID, entryID: entryID)
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
        overlayCoordinator?.refreshOverlayWordStudy(profileID: profileID, entryID: entryID)
        publishStatus("Не удалось получить перевод слов: \(error.localizedDescription)")
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
