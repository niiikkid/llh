//
//  DockLanguageBadgeController.swift
//  llh
//

import AppKit

/// Updates the Dock icon badge from the active session language; `nil` clears the badge.
@MainActor
enum DockLanguageBadgeController {
    static func update(for language: LearningLanguage?) {
        guard let language else {
            NSApp.dockTile.badgeLabel = nil
            NSApp.dockTile.display()
            return
        }

        NSApp.dockTile.badgeLabel = language.dockBadgeLabel
        NSApp.dockTile.display()
    }
}
