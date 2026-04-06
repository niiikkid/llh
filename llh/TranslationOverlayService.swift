//
//  TranslationOverlayService.swift
//  llh
//

import AppKit
import SwiftUI

@MainActor
final class TranslationOverlayService {
    private let panel = OverlayPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let hostingView = NSHostingView(rootView: CompactOverlayView(content: .loading("Обрабатываю перевод...")))
    private var dismissTask: Task<Void, Never>?

    init() {
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = hostingView
    }

    func showLoading(_ text: String = "Обрабатываю перевод...") {
        present(content: .loading(text), dismissAfter: nil)
    }

    func showTranslation(_ formattedText: StructuredFormattedText, duration: TimeInterval) {
        present(
            content: .translation(
                primaryText: overlayPrimaryText(for: formattedText),
                secondaryText: formattedText.russianTranslation
            ),
            dismissAfter: duration
        )
    }

    func showMessage(title: String, subtitle: String? = nil, duration: TimeInterval) {
        present(content: .message(title: title, subtitle: subtitle), dismissAfter: duration)
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        panel.orderOut(nil)
    }

    private func present(content: CompactOverlayContent, dismissAfter: TimeInterval?) {
        dismissTask?.cancel()
        hostingView.rootView = CompactOverlayView(content: content)

        let targetSize = hostingView.fittingSize
        let width = max(300, min(targetSize.width, 460))
        let height = max(90, targetSize.height)
        panel.setContentSize(NSSize(width: width, height: height))
        updatePanelFrame(size: NSSize(width: width, height: height))
        panel.orderFrontRegardless()

        guard let dismissAfter else { return }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(dismissAfter))
            guard !Task.isCancelled else { return }
            self?.hide()
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

    private func overlayPrimaryText(for formattedText: StructuredFormattedText) -> String {
        let trimmedPinyin = formattedText.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPinyin.isEmpty {
            return trimmedPinyin
        }

        let trimmedCleaned = formattedText.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCleaned.isEmpty {
            return trimmedCleaned
        }

        return formattedText.russianTranslation
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

private struct CompactOverlayView: View {
    let content: CompactOverlayContent

    var body: some View {
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
        .frame(width: 360)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
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
