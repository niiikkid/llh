//
//  TranslationOverlayService.swift
//  llh
//

import AppKit
import SwiftUI

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
                secondaryText: formattedText.russianTranslation
            ),
            dismissAfter: duration,
            displayMode: .temporary
        )
    }

    func showPersistentLastTranslation(_ formattedText: StructuredFormattedText) {
        present(
            content: .translation(
                primaryText: formattedText.overlayPrimaryText,
                secondaryText: formattedText.russianTranslation
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
    case translation(primaryText: String, secondaryText: String)
    case message(title: String, subtitle: String?)
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

                case .translation(let primaryText, let secondaryText):
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
