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

    var readyPayload: WordStudyPayload? {
        if case .ready(let payload) = self {
            return payload
        }
        return nil
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
        rootView: CompactOverlayHost(
            content: .loading("Обрабатываю перевод..."),
            chatViewModel: nil,
            onClose: {}
        )
    )
    private let chatPanel = OverlayPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let chatHostingView = NSHostingView(rootView: CompactOverlayChatWindowRoot(viewModel: nil))
    private var dismissTask: Task<Void, Never>?
    private var escapeKeyMonitor: Any?
    private var currentContent: CompactOverlayContent = .loading("Обрабатываю перевод...")
    private var chatViewModel: CompactOverlayChatViewModel?
    private(set) var displayMode: DisplayMode?

    init() {
        configureOverlayPanel(panel)
        panel.contentView = hostingView
        configureOverlayPanel(chatPanel)
        chatPanel.contentView = chatHostingView
    }

    func attachChatViewModel(_ viewModel: CompactOverlayChatViewModel) {
        chatViewModel = viewModel
        viewModel.onPresentationChange = { [weak self] in
            self?.handleChatPresentationChange()
        }
    }

    func showLoading(_ text: String = "Обрабатываю перевод...") {
        present(content: .loading(text), dismissAfter: nil, displayMode: .temporary, preserveChat: false)
    }

    func showTranslation(_ formattedText: StructuredFormattedText, duration: TimeInterval) {
        present(
            content: .translation(formattedText: formattedText, wordsPhase: nil),
            dismissAfter: duration,
            displayMode: .temporary,
            preserveChat: false
        )
    }

    func showTranslationWithWords(
        _ formattedText: StructuredFormattedText,
        wordsPhase: CompactOverlayWordsPhase
    ) {
        present(
            content: .translation(formattedText: formattedText, wordsPhase: wordsPhase),
            dismissAfter: nil,
            displayMode: .temporary,
            preserveChat: false
        )
    }

    func updateTranslationWithWords(
        _ formattedText: StructuredFormattedText,
        wordsPhase: CompactOverlayWordsPhase
    ) {
        guard panel.isVisible else { return }
        guard case .translation = currentContentKind else { return }
        present(
            content: .translation(formattedText: formattedText, wordsPhase: wordsPhase),
            dismissAfter: nil,
            displayMode: displayMode ?? .temporary,
            preserveChat: true
        )
    }

    func showPersistentLastTranslation(
        _ formattedText: StructuredFormattedText,
        wordsPhase: CompactOverlayWordsPhase? = nil
    ) {
        present(
            content: .translation(formattedText: formattedText, wordsPhase: wordsPhase),
            dismissAfter: nil,
            displayMode: .persistentLastTranslation,
            preserveChat: false
        )
    }

    func showMessage(title: String, subtitle: String? = nil, duration: TimeInterval) {
        present(
            content: .message(title: title, subtitle: subtitle),
            dismissAfter: duration,
            displayMode: .temporary,
            preserveChat: false
        )
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        displayMode = nil
        removeEscapeKeyMonitor()
        hideChatPanel()
        panel.orderOut(nil)
        chatViewModel?.reset(context: nil, announceChange: false)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var isShowingPersistentLastTranslation: Bool {
        panel.isVisible && displayMode == .persistentLastTranslation
    }

    private var currentContentKind: CompactOverlayContentKind {
        currentContent.contentKind
    }

    private func present(
        content: CompactOverlayContent,
        dismissAfter: TimeInterval?,
        displayMode: DisplayMode,
        preserveChat: Bool
    ) {
        dismissTask?.cancel()
        self.displayMode = displayMode
        currentContent = content
        applyChatContext(from: content, preserveChat: preserveChat)
        applyHostedView(content: content)

        let size = fittedTranslationPanelSize()
        panel.setContentSize(size)
        updateTranslationPanelFrame(size: size)
        panel.orderFrontRegardless()
        syncChatPanel()
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

    private func applyChatContext(from content: CompactOverlayContent, preserveChat: Bool) {
        guard let chatViewModel else { return }
        switch content {
        case .translation(let formattedText, let wordsPhase):
            let context = TranslationChatContext(
                formattedText: formattedText,
                words: wordsPhase?.readyPayload
            )
            if preserveChat {
                chatViewModel.updateContext(context)
            } else {
                chatViewModel.reset(context: context, announceChange: false)
            }
        case .loading, .message:
            if !preserveChat {
                chatViewModel.reset(context: nil, announceChange: false)
            }
        }
    }

    private func applyHostedView(content: CompactOverlayContent) {
        hostingView.rootView = CompactOverlayHost(
            content: content,
            chatViewModel: chatViewModel,
            onClose: { [weak self] in
                self?.handleUserDismissRequest()
            }
        )
    }

    private func handleChatPresentationChange() {
        guard panel.isVisible else { return }
        cancelAutomaticDismiss()
        syncChatPanel()
    }

    private func syncChatPanel() {
        guard let chatViewModel, chatViewModel.isSidePanelVisible, panel.isVisible else {
            hideChatPanel()
            return
        }

        chatHostingView.rootView = CompactOverlayChatWindowRoot(viewModel: chatViewModel)
        let size = fittedChatPanelSize()
        chatPanel.setContentSize(size)
        let origin = CompactOverlayLayout.chatPanelOrigin(
            translationFrame: panel.frame,
            chatSize: size,
            visibleScreen: preferredScreen()?.visibleFrame ?? panel.frame
        )
        chatPanel.setFrame(NSRect(origin: origin, size: size), display: true)
        chatPanel.orderFrontRegardless()
        if chatViewModel.wantsKeyFocus {
            chatPanel.makeKey()
        }
    }

    private func hideChatPanel() {
        chatPanel.orderOut(nil)
        chatHostingView.rootView = CompactOverlayChatWindowRoot(viewModel: nil)
    }

    private func configureOverlayPanel(_ overlayPanel: OverlayPanel) {
        overlayPanel.isFloatingPanel = true
        overlayPanel.level = .screenSaver
        overlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        overlayPanel.backgroundColor = .clear
        overlayPanel.isOpaque = false
        overlayPanel.hasShadow = false
        overlayPanel.hidesOnDeactivate = false
        overlayPanel.ignoresMouseEvents = false
        overlayPanel.becomesKeyOnlyIfNeeded = true
    }

    private func cancelAutomaticDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    private func fittedTranslationPanelSize() -> NSSize {
        hostingView.layoutSubtreeIfNeeded()
        let targetSize = hostingView.fittingSize
        return NSSize(
            width: max(300, min(targetSize.width, CompactOverlayLayout.maxWidthWithoutChat)),
            height: max(90, targetSize.height)
        )
    }

    private func fittedChatPanelSize() -> NSSize {
        chatHostingView.setFrameSize(
            NSSize(width: CompactOverlayLayout.chatCardWidth, height: CompactOverlayLayout.chatMinimumHeight)
        )
        chatHostingView.layoutSubtreeIfNeeded()
        let targetSize = chatHostingView.fittingSize
        return NSSize(
            width: CompactOverlayLayout.chatCardWidth,
            height: max(CompactOverlayLayout.chatMinimumHeight, targetSize.height)
        )
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

    private func updateTranslationPanelFrame(size: NSSize) {
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
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum PersistentLastTranslationPresentation {
    static func wordsPhase(for snapshot: LatestTranslationSnapshot) -> CompactOverlayWordsPhase? {
        guard snapshot.showWordsInCompactOverlay else { return nil }
        return CompactOverlayWordsPhase.from(
            materials: snapshot.studyMaterials,
            profileSupportsWordStudy: snapshot.profileSupportsWordStudy
        )
    }
}

enum TranslationOverlayDismissSchedule {
    /// Loading and persistent overlays stay until the user closes them; timed translations/messages auto-hide.
    static func shouldScheduleAutomaticDismiss(dismissAfter: TimeInterval?) -> Bool {
        dismissAfter != nil
    }
}
