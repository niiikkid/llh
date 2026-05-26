//
//  StudyViewModel.swift
//  llh
//

import Foundation

@MainActor
final class StudyViewModel: ObservableObject {
    @Published private(set) var studyMaterials = StudyMaterials()

    private let loadWordStudyUseCase: LoadWordStudyUseCase
    private let settings: SettingsViewModel
    private let history: HistoryViewModel
    private var reportStatus: (String) -> Void = { _ in }

    init(
        loadWordStudyUseCase: LoadWordStudyUseCase,
        settings: SettingsViewModel,
        history: HistoryViewModel
    ) {
        self.loadWordStudyUseCase = loadWordStudyUseCase
        self.settings = settings
        self.history = history
    }

    func configureStatusReporting(_ reportStatus: @escaping (String) -> Void) {
        self.reportStatus = reportStatus
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
            await loadStudyMaterial(for: selectedEntryID, forceReload: true)
        }
    }

    var selectedEntryStudyAssistantStatus: FormattingStatus? {
        guard let profileIndex = history.selectedProfileIndex,
              let entryIndex = history.selectedEntryIndex else { return nil }
        return history.profiles[profileIndex].history[entryIndex].studyMaterials.wordsStatus
    }

    var canRetryStudyAssistantData: Bool {
        guard let profileIndex = history.selectedProfileIndex,
              let entryIndex = history.selectedEntryIndex else { return false }
        let materials = history.profiles[profileIndex].history[entryIndex].studyMaterials
        return materials.wordsStatus == .failed && (materials.words?.hasContent ?? false) == false
    }

    private func loadStudyMaterial(for entryID: CapturedTextEntry.ID, forceReload: Bool) async {
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
            reportStatus("Сначала сохраните OpenAI token.")
            return
        case .missingModel:
            reportStatus("Выберите модель OpenAI.")
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
        reportStatus("Перевод слов готов.")
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
        reportStatus("Не удалось получить перевод слов: \(error.localizedDescription)")
    }

    private func syncStudyMaterialsToEditorIfSelected(entryID: CapturedTextEntry.ID) {
        guard history.selectedEntryID == entryID,
              let profileIndex = history.selectedProfileIndex,
              let entryIndex = history.profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return
        }
        studyMaterials = history.profiles[profileIndex].history[entryIndex].studyMaterials
    }
}
