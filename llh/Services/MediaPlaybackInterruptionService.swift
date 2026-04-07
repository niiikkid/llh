//
//  MediaPlaybackInterruptionService.swift
//  llh
//

import AppKit
import Foundation

struct MediaPlaybackInterruptionSession {
    static let inactive = Self(shouldResume: false, browserApplicationForResume: nil)

    let shouldResume: Bool
    let browserApplicationForResume: String?
}

struct MediaPlaybackInterruptionOutcome {
    let session: MediaPlaybackInterruptionSession
    let errorMessage: String?
}

struct MediaPlaybackInterruptionService {
    private enum ServiceError: LocalizedError {
        case unableToCreateSystemEvent
        case browserAutomationUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .unableToCreateSystemEvent:
                return "Системное событие media key не создано."
            case .browserAutomationUnavailable(let appName):
                return "Не удалось выполнить управление воспроизведением в \(appName). Проверьте разрешение Automation для приложения."
            }
        }
    }

    enum BrowserPlaybackAction {
        case pause
        case play
    }

    private static let playPauseMediaKeyCode = 16
    private static let systemDefinedEventSubtype = Int16(8)
    private static let mediaKeyEventFlags = NSEvent.ModifierFlags(rawValue: 0xA00)
    private static let keyDownState = 0xA
    private static let keyUpState = 0xB

    func pauseIfNeeded() -> MediaPlaybackInterruptionOutcome {
        let browserForBestEffortPause = NSWorkspace.shared.frontmostApplication?.localizedName
        do {
            try sendPlayPauseMediaKey()
        } catch {
            return MediaPlaybackInterruptionOutcome(session: .inactive, errorMessage: error.localizedDescription)
        }

        // Best-effort browser pause runs in background so it never delays capture start.
        if let browserForBestEffortPause,
           canAutomateBrowser(named: browserForBestEffortPause) {
            let service = self
            DispatchQueue.global(qos: .userInitiated).async {
                try? service.runBrowserPlaybackAction(.pause, in: browserForBestEffortPause)
            }
        }

        return MediaPlaybackInterruptionOutcome(
            session: MediaPlaybackInterruptionSession(shouldResume: true, browserApplicationForResume: nil),
            errorMessage: nil
        )
    }

    func resumeIfNeeded(_ session: MediaPlaybackInterruptionSession) -> String? {
        guard session.shouldResume else { return nil }

        do {
            if let browserApplicationName = session.browserApplicationForResume {
                try runBrowserPlaybackAction(.play, in: browserApplicationName)
            } else {
                try sendPlayPauseMediaKey()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func sendPlayPauseMediaKey() throws {
        try postMediaKeyEvent(withKeyState: Self.keyDownState)
        try postMediaKeyEvent(withKeyState: Self.keyUpState)
    }

    private func postMediaKeyEvent(withKeyState keyState: Int) throws {
        let data1 = Int((Self.playPauseMediaKeyCode << 16) | (keyState << 8))
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: Self.mediaKeyEventFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: Self.systemDefinedEventSubtype,
            data1: data1,
            data2: -1
        ),
        let cgEvent = event.cgEvent else {
            throw ServiceError.unableToCreateSystemEvent
        }

        cgEvent.post(tap: .cghidEventTap)
    }

    private func canAutomateBrowser(named applicationName: String) -> Bool {
        Self.browserPlaybackScript(for: applicationName, action: .pause) != nil
    }

    private func runBrowserPlaybackAction(_ action: BrowserPlaybackAction, in applicationName: String) throws {
        guard let scriptSource = Self.browserPlaybackScript(for: applicationName, action: action) else {
            throw ServiceError.browserAutomationUnavailable(applicationName)
        }

        var executionError: NSDictionary?
        guard let appleScript = NSAppleScript(source: scriptSource) else {
            throw ServiceError.browserAutomationUnavailable(applicationName)
        }
        _ = appleScript.executeAndReturnError(&executionError)

        if let executionError {
            let message = executionError[NSAppleScript.errorMessage] as? String
            throw NSError(
                domain: "MediaPlaybackInterruptionService",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: message ?? ServiceError.browserAutomationUnavailable(applicationName).localizedDescription
                ]
            )
        }
    }

    static func browserPlaybackScript(
        for applicationName: String,
        action: BrowserPlaybackAction
    ) -> String? {
        let jsAction = action == .pause ? "pause" : "play"
        let scriptBody = """
        (() => {
            const media = document.querySelector('video, audio');
            if (!media) return 'no-media';
            media.\(jsAction)();
            return media.paused ? 'paused' : 'playing';
        })();
        """

        switch applicationName {
        case "Safari":
            return """
            tell application "Safari"
                if (count of windows) = 0 then return "no-window"
                do JavaScript "\(escapeForAppleScript(scriptBody))" in current tab of front window
            end tell
            """
        case "Google Chrome", "Brave Browser", "Microsoft Edge", "Arc":
            return """
            tell application "\(applicationName)"
                if (count of windows) = 0 then return "no-window"
                set activeTab to active tab of front window
                execute activeTab javascript "\(escapeForAppleScript(scriptBody))"
            end tell
            """
        default:
            return nil
        }
    }

    private static func escapeForAppleScript(_ source: String) -> String {
        source
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
