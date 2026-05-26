//
//  EditorViewModel.swift
//  llh
//

import AppKit
import Combine
import Foundation

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var recognizedText = ""
    @Published var formattedRecognizedText: StructuredFormattedText?
    @Published var capturedImage: NSImage?
    @Published private(set) var isFormattingRecognizedText = false

    private let formatCapturedTextUseCase: FormatCapturedTextUseCase
    private let settings: SettingsViewModel
    private let history: HistoryViewModel
    private let study: StudyViewModel
    private let overlay: TranslationOverlayCoordinator
    private var reportStatus: (String) -> Void = { _ in }

    init(
        formatCapturedTextUseCase: FormatCapturedTextUseCase,
        settings: SettingsViewModel,
        history: HistoryViewModel,
        study: StudyViewModel,
        overlay: TranslationOverlayCoordinator
    ) {
        self.formatCapturedTextUseCase = formatCapturedTextUseCase
        self.settings = settings
        self.history = history
        self.study = study
        self.overlay = overlay
    }

    func configureStatusReporting(_ reportStatus: @escaping (String) -> Void) {
        self.reportStatus = reportStatus
    }

    func updateSelectedText(_ newText: String) {
        recognizedText = newText
        guard history.updateSelectedEntryText(newText) else { return }
        formattedRecognizedText = nil
        study.clearStudyMaterials()
    }

    func retryFormattingForSelectedEntry() {
        guard let selectedEntryID = history.selectedEntryID else { return }
        Task {
            await formatEntryText(entryID: selectedEntryID, forceRetry: true)
        }
    }

    func syncSelectionFromHistory() {
        guard let profileIndex = history.selectedProfileIndex,
              let entryIndex = history.selectedEntryIndex else {
            recognizedText = ""
            formattedRecognizedText = nil
            study.clearStudyMaterials()
            capturedImage = nil
            return
        }
        let entry = history.profiles[profileIndex].history[entryIndex]
        recognizedText = entry.text
        formattedRecognizedText = entry.formattedText
        study.applyStudyMaterialsFromEntry(entry.studyMaterials)
        capturedImage = entry.image
    }

    func applyCapturePreviewWithoutEntry(_ image: NSImage?) {
        capturedImage = image
        recognizedText = ""
    }

    func handlePostCapture(entryID: CapturedTextEntry.ID, markOverlayAwaiting: Bool) {
        if markOverlayAwaiting {
            overlay.markEntryAwaitingFormattedResult(entryID)
        }
        Task {
            await formatEntryText(entryID: entryID, forceRetry: false)
        }
    }

    var canRetryFormatting: Bool {
        guard let profileIndex = history.selectedProfileIndex,
              let entryIndex = history.selectedEntryIndex else { return false }
        let entry = history.profiles[profileIndex].history[entryIndex]
        return entry.formattingStatus == .failed && (entry.formattedText?.hasContent ?? false) == false
    }

    var selectedEntryFormattingStatus: FormattingStatus? {
        guard let profileIndex = history.selectedProfileIndex,
              let entryIndex = history.selectedEntryIndex else { return nil }
        return history.profiles[profileIndex].history[entryIndex].formattingStatus
    }

    private func formatEntryText(entryID: CapturedTextEntry.ID, forceRetry: Bool) async {
        guard !isFormattingRecognizedText else { return }
        guard let profileIndex = history.selectedProfileIndex else { return }
        guard let entryIndex = history.profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        let entry = history.profiles[profileIndex].history[entryIndex]
        let request = FormatCapturedTextRequest(
            rawText: entry.text,
            targetLanguage: history.profiles[profileIndex].learningLanguage,
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
            reportStatus("Сначала сохраните OpenAI token.")
            overlay.handleFormattingPreflightFailure(entryID: entryID, title: "Сначала сохраните OpenAI token")
            return
        case .missingModel:
            reportStatus("Выберите модель OpenAI.")
            overlay.handleFormattingPreflightFailure(entryID: entryID, title: "Выберите модель OpenAI")
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
        guard let profileID = history.selectedProfileID else { return }
        guard history.mutateEntry(profileID: profileID, entryID: entryID, { entry in
            entry.formattedText = formatted
            entry.formattingStatus = .succeeded
        }) else {
            return
        }

        if history.selectedEntryID == entryID {
            formattedRecognizedText = formatted
        }
        history.persist()
        reportStatus("Форматирование завершено.")
        overlay.handleFormattingSuccess(entryID: entryID, formatted: formatted)
    }

    private func applyFormattingFailure(entryID: CapturedTextEntry.ID, error: Error) {
        guard let profileID = history.selectedProfileID else { return }
        guard history.mutateEntry(profileID: profileID, entryID: entryID, { entry in
            entry.formattedText = nil
            entry.formattingStatus = .failed
        }) else {
            return
        }

        if history.selectedEntryID == entryID {
            formattedRecognizedText = nil
        }
        history.persist()
        reportStatus("Не удалось отформатировать текст: \(error.localizedDescription)")
        overlay.handleFormattingFailure(entryID: entryID, error: error)
    }

    private func beginFormattingEntry(entryID: CapturedTextEntry.ID) -> Bool {
        guard let profileID = history.selectedProfileID else { return false }
        isFormattingRecognizedText = true
        guard history.mutateEntry(profileID: profileID, entryID: entryID, { entry in
            entry.formattingStatus = .processing
        }) else {
            isFormattingRecognizedText = false
            return false
        }
        history.persist()
        return true
    }

    private func endFormattingEntry() {
        isFormattingRecognizedText = false
    }
}
