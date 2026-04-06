//
//  RegionSelectionService.swift
//  llh
//

import AppKit
import Foundation

@MainActor
final class RegionSelectionService {
    enum SelectionError: LocalizedError {
        case cancelled
        case noScreen

        var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Выделение отменено."
            case .noScreen:
                return "Не удалось получить экран."
            }
        }
    }

    private var windows: [NSWindow] = []
    private var continuation: CheckedContinuation<CGRect, Error>?

    func selectRegion() async throws -> CGRect {
        guard continuation == nil else { throw SelectionError.cancelled }
        guard !NSScreen.screens.isEmpty else { throw SelectionError.noScreen }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            showOverlayWindows()
        }
    }

    private func showOverlayWindows() {
        windows = NSScreen.screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false

            let overlayView = SelectionOverlayView { [weak self, weak window] rect in
                guard let self, let window else { return }
                let absoluteRect = rect.offsetBy(dx: window.frame.origin.x, dy: window.frame.origin.y)
                self.finish(with: .success(absoluteRect.standardized))
            } onCancel: { [weak self] in
                self?.finish(with: .failure(SelectionError.cancelled))
            }

            window.contentView = overlayView
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(overlayView)
            return window
        }
    }

    private func finish(with result: Result<CGRect, Error>) {
        let continuation = continuation
        self.continuation = nil

        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()

        switch result {
        case .success(let rect):
            continuation?.resume(returning: rect)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}

private final class SelectionOverlayView: NSView {
    private let onComplete: (CGRect) -> Void
    private let onCancel: () -> Void

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    init(onComplete: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onCancel()
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let rect = selectionRect, rect.width > 4, rect.height > 4 else {
            onCancel()
            return
        }
        onComplete(rect)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.28).setFill()
        dirtyRect.fill()

        guard let selectionRect else { return }

        NSColor.clear.setFill()
        selectionRect.fill(using: .clear)

        NSColor.white.withAlphaComponent(0.95).setStroke()
        let path = NSBezierPath(rect: selectionRect)
        path.lineWidth = 2
        path.setLineDash([8, 6], count: 2, phase: 0)
        path.stroke()
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }
}
