//
//  AppShortcutsCoordinator.swift
//  llh
//

import Foundation
import KeyboardShortcuts

@MainActor
struct AppShortcutHandlers {
    let onCaptureArea: () -> Void
    let onSwitchOCREngine: () -> Void
    let onCloseTranslationOverlay: () -> Void
    let onToggleLastTranslationOverlay: () -> Void
}

/// Registers global keyboard shortcuts; feature ViewModels stay free of `KeyboardShortcuts` lifecycle.
@MainActor
final class AppShortcutsCoordinator {
    init(handlers: AppShortcutHandlers) {
        KeyboardShortcuts.onKeyUp(for: .captureArea) {
            Task { @MainActor in
                handlers.onCaptureArea()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .switchOCREngine) {
            Task { @MainActor in
                handlers.onSwitchOCREngine()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .closeTranslationOverlay) {
            Task { @MainActor in
                handlers.onCloseTranslationOverlay()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .toggleLastTranslationOverlay) {
            Task { @MainActor in
                handlers.onToggleLastTranslationOverlay()
            }
        }
    }
}
