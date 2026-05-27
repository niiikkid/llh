//
//  MainWindowActivator.swift
//  llh
//

import AppKit
import SwiftUI

/// Brings the single main `WindowGroup` forward without creating duplicates from the menu bar.
@MainActor
enum MainWindowActivator {
    static let accessibilityIdentifier = "llh.main-window"

    /// Returns `true` when an existing main window was found and ordered front.
    static func activateExisting() -> Bool {
        guard let window = existingMainWindow else { return false }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    private static var existingMainWindow: NSWindow? {
        NSApp.windows.first { window in
            window.accessibilityIdentifier == accessibilityIdentifier
        }
    }
}

/// Tags the hosting `NSWindow` so menu bar actions can find it without calling `openWindow` again.
struct MainWindowIdentityView: NSViewRepresentable {
    func makeNSView(context: Context) -> MainWindowIdentityHostView {
        MainWindowIdentityHostView()
    }

    func updateNSView(_ nsView: MainWindowIdentityHostView, context: Context) {
        nsView.applyMainWindowIdentifier()
    }
}

private final class MainWindowIdentityHostView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyMainWindowIdentifier()
    }

    func applyMainWindowIdentifier() {
        window?.accessibilityIdentifier = MainWindowActivator.accessibilityIdentifier
    }
}
