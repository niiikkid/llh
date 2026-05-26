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
    }

    func close(cancelPendingResult: Bool = true) {
        if cancelPendingResult {
            entryAwaitingFormattedResult = nil
        }
        translationOverlayService.hide()
    }

    func toggleLastTranslation() {
        if translationOverlayService.isShowingPersistentLastTranslation {
            close()
            return
        }

        entryAwaitingFormattedResult = nil

        guard let formattedText = LatestTranslationLookup.latestFormattedText(in: history.profiles) else {
            translationOverlayService.showMessage(title: "Пока нет готового перевода", duration: 2)
            return
        }

        translationOverlayService.showPersistentLastTranslation(formattedText)
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
            translationOverlayService.showTranslation(
                formatted,
                duration: settings.calculatedTranslationOverlayDuration(for: formatted)
            )
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
}
