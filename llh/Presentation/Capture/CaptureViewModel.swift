//
//  CaptureViewModel.swift
//  llh
//

import AppKit
import Foundation

@MainActor
final class CaptureViewModel: ObservableObject {
    enum TriggerSource {
        case interface
        case hotkey
    }

    @Published private(set) var isProcessing = false
    @Published private(set) var showPermissionHelp = false

    private let permissionService: ScreenRecordingPermissionChecking
    private let captureRegionUseCase: CaptureRegionUseCase
    private let settings: SettingsViewModel
    private let history: HistoryViewModel
    private let translationOverlayService: TranslationOverlayService
    private let shouldUseCompactOverlay: () -> Bool

    private var reportStatus: (String) -> Void = { _ in }
    private var prepareForInterfaceCapture: () -> Void = {}
    private var syncSelectionToEditor: () -> Void = {}
    private var applyCapturePreviewWithoutEntry: (NSImage?) -> Void = { _ in }
    private var clearOverlayAwaitingFormat: () -> Void = {}
    private var onPostCapture: (CapturedTextEntry.ID, TriggerSource) -> Void = { _, _ in }

    init(
        permissionService: ScreenRecordingPermissionChecking,
        captureRegionUseCase: CaptureRegionUseCase,
        settings: SettingsViewModel,
        history: HistoryViewModel,
        translationOverlayService: TranslationOverlayService,
        shouldUseCompactOverlay: @escaping () -> Bool
    ) {
        self.permissionService = permissionService
        self.captureRegionUseCase = captureRegionUseCase
        self.settings = settings
        self.history = history
        self.translationOverlayService = translationOverlayService
        self.shouldUseCompactOverlay = shouldUseCompactOverlay
    }

    func configureStatusReporting(_ reportStatus: @escaping (String) -> Void) {
        self.reportStatus = reportStatus
    }

    func configurePrepareForInterfaceCapture(_ prepare: @escaping () -> Void) {
        prepareForInterfaceCapture = prepare
    }

    func configureSelectionSync(_ syncSelectionToEditor: @escaping () -> Void) {
        self.syncSelectionToEditor = syncSelectionToEditor
    }

    func configureCapturePreviewWithoutEntry(_ apply: @escaping (NSImage?) -> Void) {
        applyCapturePreviewWithoutEntry = apply
    }

    func configureOverlayAwaitingFormatReset(_ clear: @escaping () -> Void) {
        clearOverlayAwaitingFormat = clear
    }

    func configurePostCapture(_ handler: @escaping (CapturedTextEntry.ID, TriggerSource) -> Void) {
        onPostCapture = handler
    }

    func triggerCapture() {
        Task {
            prepareForInterfaceCapture()
            await startCaptureFlow(triggeredBy: .interface)
        }
    }

    func triggerCaptureFromHotkey() {
        Task {
            await startCaptureFlow(triggeredBy: .hotkey)
        }
    }

    func refreshPermissionState() {
        let granted = permissionService.hasPermission
        showPermissionHelp = !granted
        if granted {
            reportStatus("Готово к захвату.")
        }
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }

    private func startCaptureFlow(triggeredBy source: TriggerSource) async {
        guard !isProcessing else { return }

        isProcessing = true
        reportStatus("Выберите область на экране...")

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
                reportStatus("Нет доступа к Screen Recording. Откройте System Settings и включите доступ.")
            case .selectionCancelled:
                showPermissionHelp = false
                reportStatus("Выделение отменено.")
                clearOverlayAwaitingFormat()
                if source == .hotkey, shouldUseCompactOverlay() {
                    translationOverlayService.hide()
                }
            case .noTextFound(let image):
                showPermissionHelp = false
                applyCapturePreviewWithoutEntry(NSImage(cgImage: image, size: .zero))
                reportStatus("Текст не найден.")
                clearOverlayAwaitingFormat()
                if source == .hotkey, shouldUseCompactOverlay() {
                    translationOverlayService.showMessage(title: "Текст не найден", duration: 3)
                }
            case .captured(let image, let text):
                showPermissionHelp = false
                let imagePreview = NSImage(cgImage: image, size: .zero)
                let entry = CapturedTextEntry(text: text, image: imagePreview)
                guard let selectedProfileIndex = history.selectedProfileIndex else { return }
                history.insertEntry(profileIndex: selectedProfileIndex, entry: entry)
                syncSelectionToEditor()
                history.persist()
                reportStatus("Готово. Запись добавлена в историю. Форматирую текст...")
                if source == .hotkey, shouldUseCompactOverlay() {
                    translationOverlayService.showLoading()
                }
                onPostCapture(entry.id, source)
            }
        } catch {
            showPermissionHelp = false
            reportStatus("Ошибка: \(error.localizedDescription)")
            clearOverlayAwaitingFormat()
            if source == .hotkey, shouldUseCompactOverlay() {
                translationOverlayService.showMessage(
                    title: "Ошибка обработки",
                    subtitle: error.localizedDescription,
                    duration: 3
                )
            }
        }
    }
}
