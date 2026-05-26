//
//  MainViewModel.swift
//  llh
//

import AppKit
import Combine
import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    @Published var statusMessage = "Нажмите shortcut и выделите область."

    let settings: SettingsViewModel
    let history: HistoryViewModel
    let capture: CaptureViewModel
    let study: StudyViewModel
    let editor: EditorViewModel

    private let overlay: TranslationOverlayCoordinator
    private var cancellables = Set<AnyCancellable>()
    private let shortcutsCoordinator: AppShortcutsCoordinator

    init(dependencies: AppDependencyContainer) {
        let settingsViewModel = SettingsViewModel(
            manageOpenAISettingsUseCase: dependencies.manageOpenAISettingsUseCase,
            translationOverlayService: dependencies.translationOverlayService
        )
        settings = settingsViewModel
        history = HistoryViewModel(
            manageHistoryUseCase: dependencies.manageHistoryUseCase,
            manageProfilesUseCase: dependencies.manageProfilesUseCase,
            defaultLearningLanguage: {
                settingsViewModel.defaultNewProfileLearningLanguage
            }
        )
        study = StudyViewModel(
            loadWordStudyUseCase: dependencies.loadWordStudyUseCase,
            settings: settingsViewModel,
            history: history
        )
        overlay = TranslationOverlayCoordinator(
            translationOverlayService: dependencies.translationOverlayService,
            settings: settingsViewModel,
            history: history,
            shouldUseCompactOverlay: { !NSApp.isActive }
        )
        editor = EditorViewModel(
            formatCapturedTextUseCase: dependencies.formatCapturedTextUseCase,
            settings: settingsViewModel,
            history: history,
            study: study,
            overlay: overlay
        )
        capture = CaptureViewModel(
            permissionService: dependencies.permissionService,
            captureRegionUseCase: dependencies.captureRegionUseCase,
            settings: settingsViewModel,
            history: history,
            translationOverlayService: dependencies.translationOverlayService,
            shouldUseCompactOverlay: { !NSApp.isActive }
        )
        shortcutsCoordinator = AppShortcutsCoordinator(
            handlers: AppShortcutHandlers(
                onCaptureArea: { [weak capture, weak overlay] in
                    overlay?.close()
                    capture?.triggerCaptureFromHotkey()
                },
                onSwitchOCREngine: { [weak settings, weak overlay] in
                    overlay?.close(cancelPendingResult: false)
                    settings?.switchToNextOCREngine(triggeredByHotkey: true)
                },
                onCloseTranslationOverlay: { [weak overlay] in
                    overlay?.close()
                },
                onToggleLastTranslationOverlay: { [weak overlay] in
                    overlay?.toggleLastTranslation()
                }
            )
        )
        settings.configureStatusReporting { [weak self] message in
            self?.statusMessage = message
        }
        history.configureStatusReporting { [weak self] message in
            self?.statusMessage = message
        }
        study.configureStatusReporting { [weak self] message in
            self?.statusMessage = message
        }
        editor.configureStatusReporting { [weak self] message in
            self?.statusMessage = message
        }
        history.configureSelectionSync { [weak editor] in
            editor?.syncSelectionFromHistory()
        }
        history.configureNewProfileLanguagePersistence { [weak settings] language in
            settings?.setDefaultNewProfileLearningLanguage(language)
        }
        capture.configureStatusReporting { [weak self] message in
            self?.statusMessage = message
        }
        capture.configurePrepareForInterfaceCapture { [weak self] in
            self?.closeTranslationOverlay()
        }
        capture.configureSelectionSync { [weak editor] in
            editor?.syncSelectionFromHistory()
        }
        capture.configureCapturePreviewWithoutEntry { [weak editor] image in
            editor?.applyCapturePreviewWithoutEntry(image)
        }
        capture.configureOverlayAwaitingFormatReset { [weak overlay] in
            overlay?.clearAwaitingFormattedEntry()
        }
        capture.configurePostCapture { [weak editor] entryID, source in
            editor?.handlePostCapture(
                entryID: entryID,
                markOverlayAwaiting: source == .hotkey && !NSApp.isActive
            )
        }
        subscribeToChildViewModelChanges(settings)
        subscribeToChildViewModelChanges(history)
        subscribeToChildViewModelChanges(capture)
        subscribeToChildViewModelChanges(study)
        subscribeToChildViewModelChanges(editor)

        history.loadFromDisk()
        capture.refreshPermissionState()
    }

    func closeTranslationOverlay(cancelPendingResult: Bool = true) {
        overlay.close(cancelPendingResult: cancelPendingResult)
    }

    func toggleLastTranslationOverlay() {
        overlay.toggleLastTranslation()
    }

    func retryStudyAssistantDataForSelectedEntry() {
        study.retryStudyAssistantDataForSelectedEntry()
    }

    var selectedEntryStudyAssistantStatus: FormattingStatus? {
        study.selectedEntryStudyAssistantStatus
    }

    var canRetryStudyAssistantData: Bool {
        study.canRetryStudyAssistantData
    }

    private func subscribeToChildViewModelChanges(_ child: some ObservableObject) {
        child.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
