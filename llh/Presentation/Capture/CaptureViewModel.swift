//
//  CaptureViewModel.swift
//  llh
//

import AppKit
import Combine
import Foundation

@MainActor
final class CaptureViewModel: ObservableObject {
    enum TriggerSource {
        case interface
        case hotkey
    }

    @Published private(set) var isProcessing = false
    @Published private(set) var showPermissionHelp = false
    @Published private(set) var permissionStatus: ScreenRecordingPermissionStatus = .denied
    @Published private(set) var statusMessage = "Нажмите shortcut и выделите область."

    private let permissionService: ScreenRecordingPermissionChecking
    private let captureRegionUseCase: CaptureRegionUseCase
    private let settings: SettingsViewModel
    private let history: HistoryViewModel
    private let translationOverlayService: TranslationOverlayService
    private let shouldUseCompactOverlay: () -> Bool

    private var activeCaptureTask: Task<Void, Never>?

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
        refreshPermissionState()
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
        startCaptureTask(triggeredBy: .interface) { [self] in
            prepareForInterfaceCapture()
        }
    }

    func triggerCaptureFromHotkey() {
        if isProcessing {
            cancelActiveCapture()
            return
        }
        startCaptureTask(triggeredBy: .hotkey)
    }

    func refreshPermissionState() {
        permissionStatus = permissionService.permissionStatus
        showPermissionHelp = !permissionStatus.isAuthorized
        if permissionStatus.isAuthorized {
            publishStatus("Готово к захвату.")
        }
    }

    func requestScreenRecordingAccess() {
        _ = permissionService.requestPermission()
        refreshPermissionState()
        if permissionStatus.isAuthorized {
            publishStatus("Доступ к Screen Recording предоставлен.")
        } else {
            publishStatus("Доступ не предоставлен. Включите приложение в System Settings.")
        }
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }

    func cancelActiveCapture() {
        captureRegionUseCase.cancelActiveCapture()
        activeCaptureTask?.cancel()
        activeCaptureTask = nil
        isProcessing = false
        publishStatus("Захват отменён.")
        clearOverlayAwaitingFormat()
    }

    private func startCaptureTask(
        triggeredBy source: TriggerSource,
        prepare: @escaping () -> Void = {}
    ) {
        guard !isProcessing else { return }

        activeCaptureTask?.cancel()
        activeCaptureTask = Task {
            prepare()
            await startCaptureFlow(triggeredBy: source)
        }
    }

    private func startCaptureFlow(triggeredBy source: TriggerSource) async {
        guard !isProcessing else { return }

        isProcessing = true
        publishStatus("Выберите область на экране...")

        defer {
            isProcessing = false
            activeCaptureTask = nil
        }

        let configuration = CaptureRegionConfiguration(
            ocrEngine: settings.selectedOCREngine,
            apiKey: settings.openAIAPIKey(),
            selectedModelID: settings.openAIModelID()
        )

        do {
            switch try await captureRegionUseCase.execute(configuration: configuration) {
            case .permissionDenied:
                showPermissionHelp = true
                publishStatus("Нет доступа к Screen Recording. Запросите доступ или откройте System Settings.")
            case .selectionCancelled:
                showPermissionHelp = false
                publishStatus("Выделение отменено.")
                clearOverlayAwaitingFormat()
                if source == .hotkey, shouldUseCompactOverlay() {
                    translationOverlayService.hide()
                }
            case .noTextFound(let image):
                showPermissionHelp = false
                applyCapturePreviewWithoutEntry(NSImage(cgImage: image, size: .zero))
                publishStatus("Текст не найден.")
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
                publishStatus("Готово. Запись добавлена в историю. Форматирую текст...")
                if source == .hotkey, shouldUseCompactOverlay() {
                    translationOverlayService.showLoading()
                }
                onPostCapture(entry.id, source)
            }
        } catch is CancellationError {
            showPermissionHelp = false
            publishStatus("Захват отменён.")
            clearOverlayAwaitingFormat()
            if source == .hotkey, shouldUseCompactOverlay() {
                translationOverlayService.hide()
            }
        } catch {
            showPermissionHelp = false
            publishStatus("Ошибка: \(error.localizedDescription)")
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

    private func publishStatus(_ message: String) {
        statusMessage = message
    }
}
