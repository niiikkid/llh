//
//  TranslationOverlayCoordinator.swift
//  llh
//

import AppKit
import Foundation

@MainActor
final class TranslationOverlayCoordinator {
    private let translationOverlayService: TranslationOverlayService
    private let settings: SettingsViewModel
    private let history: HistoryViewModel
    private let shouldUseCompactOverlay: () -> Bool
    private var entryAwaitingFormattedResult: CapturedTextEntry.ID?
    private var overlayWordStudyEntryID: CapturedTextEntry.ID?
    private var overlayWordStudyProfileID: LearningProfile.ID?
    private var overlayWordStudyFormatted: StructuredFormattedText?

    init(
        translationOverlayService: TranslationOverlayService,
        settings: SettingsViewModel,
        history: HistoryViewModel,
        shouldUseCompactOverlay: @escaping () -> Bool
    ) {
        self.translationOverlayService = translationOverlayService
        self.settings = settings
        self.history = history
        self.shouldUseCompactOverlay = shouldUseCompactOverlay
        translationOverlayService.onRequestClose = { [weak self] in
            self?.close()
        }
    }

    func close(cancelPendingResult: Bool = true) {
        if cancelPendingResult {
            entryAwaitingFormattedResult = nil
        }
        clearOverlayWordStudyTracking()
        translationOverlayService.hide()
    }

    func toggleLastTranslation() {
        if translationOverlayService.isShowingPersistentLastTranslation {
            close()
            return
        }

        entryAwaitingFormattedResult = nil
        clearOverlayWordStudyTracking()

        guard let latest = LatestTranslationLookup.latest(in: history.profiles) else {
            translationOverlayService.showMessage(title: "Пока нет готового перевода", duration: 2)
            return
        }

        if latest.showWordsInCompactOverlay {
            overlayWordStudyEntryID = latest.entryID
            overlayWordStudyProfileID = latest.profileID
            overlayWordStudyFormatted = latest.formattedText
        }

        translationOverlayService.showPersistentLastTranslation(
            latest.formattedText,
            wordsPhase: PersistentLastTranslationPresentation.wordsPhase(for: latest)
        )
    }

    func clearAwaitingFormattedEntry() {
        entryAwaitingFormattedResult = nil
    }

    func markEntryAwaitingFormattedResult(_ entryID: CapturedTextEntry.ID) {
        entryAwaitingFormattedResult = entryID
    }

    func handleFormattingPreflightFailure(entryID: CapturedTextEntry.ID, title: String) {
        guard entryAwaitingFormattedResult == entryID else { return }
        translationOverlayService.showMessage(title: title, duration: 3)
        entryAwaitingFormattedResult = nil
    }

    func handleFormattingSuccess(entryID: CapturedTextEntry.ID, formatted: StructuredFormattedText) {
        guard entryAwaitingFormattedResult == entryID else { return }
        if shouldUseCompactOverlay() {
            let profile = history.activeProfile
            if profile?.showWordsInCompactOverlay == true {
                overlayWordStudyEntryID = entryID
                overlayWordStudyProfileID = profile?.id
                overlayWordStudyFormatted = formatted
                let materials = studyMaterials(profileID: profile?.id, entryID: entryID)
                translationOverlayService.showTranslationWithWords(
                    formatted,
                    wordsPhase: CompactOverlayWordsPhase.from(
                        materials: materials,
                        profileSupportsWordStudy: history.currentProfileSupportsWordStudy
                    )
                )
            } else {
                clearOverlayWordStudyTracking()
                translationOverlayService.showTranslation(
                    formatted,
                    duration: settings.calculatedTranslationOverlayDuration(for: formatted)
                )
            }
        } else {
            translationOverlayService.hide()
        }
        entryAwaitingFormattedResult = nil
    }

    func handleFormattingFailure(entryID: CapturedTextEntry.ID, error: Error) {
        guard entryAwaitingFormattedResult == entryID else { return }
        if shouldUseCompactOverlay() {
            translationOverlayService.showMessage(
                title: "Не удалось получить перевод",
                subtitle: error.localizedDescription,
                duration: 3
            )
        } else {
            translationOverlayService.hide()
        }
        entryAwaitingFormattedResult = nil
    }

    func refreshOverlayWordStudy(
        profileID: LearningProfile.ID,
        entryID: CapturedTextEntry.ID
    ) {
        guard overlayWordStudyEntryID == entryID,
              overlayWordStudyProfileID == profileID,
              let formatted = overlayWordStudyFormatted,
              translationOverlayService.isVisible else {
            return
        }
        let materials = studyMaterials(profileID: profileID, entryID: entryID)
        translationOverlayService.updateTranslationWithWords(
            formatted,
            wordsPhase: CompactOverlayWordsPhase.from(
                materials: materials,
                profileSupportsWordStudy: profileSupportsWordStudy(profileID: profileID)
            )
        )
    }

    private func clearOverlayWordStudyTracking() {
        overlayWordStudyEntryID = nil
        overlayWordStudyProfileID = nil
        overlayWordStudyFormatted = nil
    }

    private func studyMaterials(
        profileID: LearningProfile.ID?,
        entryID: CapturedTextEntry.ID
    ) -> StudyMaterials? {
        guard let profileID,
              let profileIndex = history.profiles.firstIndex(where: { $0.id == profileID }),
              let entryIndex = history.profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return nil
        }
        return history.profiles[profileIndex].history[entryIndex].studyMaterials
    }

    private func profileSupportsWordStudy(profileID: LearningProfile.ID) -> Bool {
        guard let profile = history.profiles.first(where: { $0.id == profileID }) else {
            return false
        }
        return profile.learningLanguage.supportsWordStudy
    }
}
