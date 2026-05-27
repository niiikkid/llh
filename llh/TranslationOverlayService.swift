//
//  TranslationOverlayService.swift
//  llh
//

import AppKit
import SwiftUI

enum CompactOverlayWordsPhase: Equatable {
    case loading
    case ready(WordStudyPayload)
    case failed
    case unavailable

    static func from(
        materials: StudyMaterials?,
        profileSupportsWordStudy: Bool
    ) -> Self {
        guard profileSupportsWordStudy else {
            return .unavailable
        }
        guard let materials else {
            return .loading
        }
        switch materials.wordsStatus {
        case .processing, .notRequested:
            return .loading
        case .succeeded:
            if let payload = materials.words, payload.hasContent {
                return .ready(payload)
            }
            return .loading
        case .failed:
            return .failed
        }
    }
}

@MainActor
final class TranslationOverlayService {
    enum DisplayMode: Equatable {
        case temporary
        case persistentLastTranslation
    }

    /// Invoked when the user dismisses the overlay via the close button or Escape.
    var onRequestClose: (() -> Void)?

    private let panel = OverlayPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let hostingView = NSHostingView(
        rootView: CompactOverlayView(content: .loading("Обрабатываю перевод..."), onClose: {})
    )
    private var dismissTask: Task<Void, Never>?
    private var escapeKeyMonitor: Any?
    private(set) var displayMode: DisplayMode?

    init() {
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.contentView = hostingView
    }

    func showLoading(_ text: String = "Обрабатываю перевод...") {
        present(content: .loading(text), dismissAfter: nil, displayMode: .temporary)
    }

    func showTranslation(_ formattedText: StructuredFormattedText, duration: TimeInterval) {
        present(
            content: .translation(
                primaryText: formattedText.overlayPrimaryText,
                secondaryText: formattedText.russianTranslation,
                wordsPhase: nil
            ),
            dismissAfter: duration,
            displayMode: .temporary
        )
    }

    func showTranslationWithWords(
        _ formattedText: StructuredFormattedText,
        wordsPhase: CompactOverlayWordsPhase
    ) {
        present(
            content: .translation(
                primaryText: formattedText.overlayPrimaryText,
                secondaryText: formattedText.russianTranslation,
                wordsPhase: wordsPhase
            ),
            dismissAfter: nil,
            displayMode: .temporary
        )
    }

    func updateTranslationWithWords(
        _ formattedText: StructuredFormattedText,
        wordsPhase: CompactOverlayWordsPhase
    ) {
        guard panel.isVisible else { return }
        guard case .translation = currentContentKind else { return }
        present(
            content: .translation(
                primaryText: formattedText.overlayPrimaryText,
                secondaryText: formattedText.russianTranslation,
                wordsPhase: wordsPhase
            ),
            dismissAfter: nil,
            displayMode: displayMode ?? .temporary
        )
    }

    func showPersistentLastTranslation(_ formattedText: StructuredFormattedText) {
        present(
            content: .translation(
                primaryText: formattedText.overlayPrimaryText,
                secondaryText: formattedText.russianTranslation,
                wordsPhase: nil
            ),
            dismissAfter: nil,
            displayMode: .persistentLastTranslation
        )
    }

    func showMessage(title: String, subtitle: String? = nil, duration: TimeInterval) {
        present(content: .message(title: title, subtitle: subtitle), dismissAfter: duration, displayMode: .temporary)
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        displayMode = nil
        removeEscapeKeyMonitor()
        panel.orderOut(nil)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var isShowingPersistentLastTranslation: Bool {
        panel.isVisible && displayMode == .persistentLastTranslation
    }

    private var currentContentKind: CompactOverlayContentKind {
        hostingView.rootView.contentKind
    }

    private func present(content: CompactOverlayContent, dismissAfter: TimeInterval?, displayMode: DisplayMode) {
        dismissTask?.cancel()
        self.displayMode = displayMode
        hostingView.rootView = CompactOverlayView(content: content) { [weak self] in
            self?.handleUserDismissRequest()
        }

        let targetSize = hostingView.fittingSize
        let width = max(300, min(targetSize.width, 460))
        let height = max(90, targetSize.height)
        panel.setContentSize(NSSize(width: width, height: height))
        updatePanelFrame(size: NSSize(width: width, height: height))
        panel.orderFrontRegardless()
        installEscapeKeyMonitor()

        guard TranslationOverlayDismissSchedule.shouldScheduleAutomaticDismiss(dismissAfter: dismissAfter) else {
            return
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(dismissAfter ?? 0))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    private func handleUserDismissRequest() {
        if let onRequestClose {
            onRequestClose()
        } else {
            hide()
        }
    }

    private func installEscapeKeyMonitor() {
        removeEscapeKeyMonitor()
        escapeKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                self.handleUserDismissRequest()
            }
        }
    }

    private func removeEscapeKeyMonitor() {
        if let escapeKeyMonitor {
            NSEvent.removeMonitor(escapeKeyMonitor)
            self.escapeKeyMonitor = nil
        }
    }

    private func updatePanelFrame(size: NSSize) {
        guard let screen = preferredScreen() else { return }
        let origin = CGPoint(
            x: screen.visibleFrame.midX - (size.width / 2),
            y: screen.visibleFrame.minY + 32
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func preferredScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let screenUnderMouse = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screenUnderMouse
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private enum CompactOverlayContent: Equatable {
    case loading(String)
    case translation(primaryText: String, secondaryText: String, wordsPhase: CompactOverlayWordsPhase?)
    case message(title: String, subtitle: String?)

    var contentKind: CompactOverlayContentKind {
        switch self {
        case .loading: .loading
        case .translation: .translation
        case .message: .message
        }
    }
}

private enum CompactOverlayContentKind {
    case loading
    case translation
    case message
}

enum TranslationOverlayDismissSchedule {
    /// Loading and persistent overlays stay until the user closes them; timed translations/messages auto-hide.
    static func shouldScheduleAutomaticDismiss(dismissAfter: TimeInterval?) -> Bool {
        dismissAfter != nil
    }
}

private struct CompactOverlayView: View {
    let content: CompactOverlayContent
    let onClose: () -> Void

    var contentKind: CompactOverlayContentKind {
        content.contentKind
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                switch content {
                case .loading(let text):
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                case .translation(let primaryText, let secondaryText, let wordsPhase):
                    if !primaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(primaryText)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                    }

                    Text(secondaryText)
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    if let wordsPhase {
                        CompactOverlayWordsSectionView(phase: wordsPhase)
                    }

                case .message(let title, let subtitle):
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(subtitle)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                    .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(10)
            .help("Закрыть (Escape)")
        }
        .frame(width: 360)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.24))
            )
    }
}

private struct CompactOverlayWordsSectionView: View {
    let phase: CompactOverlayWordsPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 2)

            switch phase {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Перевожу слова…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            case .ready(let payload):
                Text("Перевод слов")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(payload.entries.enumerated()), id: \.offset) { _, entry in
                            CompactOverlayWordEntryRowView(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 180)

            case .failed:
                Text("Не удалось перевести слова.")
                    .font(.caption)
                    .foregroundStyle(.orange)

            case .unavailable:
                Text("Перевод слов недоступен для этой сессии.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompactOverlayWordEntryRowView: View {
    let entry: WordStudyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.termPinyin)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                if !entry.russianPronunciationGuide.isEmpty {
                    Text("(\(entry.russianPronunciationGuide))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text("—")
                    .foregroundStyle(.secondary)
                Text(entry.termTranslation)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
