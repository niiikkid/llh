# Phase 4 Capture ViewModel and Shortcuts Coordinator Completion

> Source: llh project refactor session
> Collected: 2026-05-26
> Published: Unknown

## Summary

Third increment of Phase 4: capture flow and Screen Recording permission UI state moved to `CaptureViewModel`; global hotkey registration moved to `AppShortcutsCoordinator`.

## Code changes

- `llh/Presentation/Capture/CaptureViewModel.swift` — `isProcessing`, `showPermissionHelp`, `CaptureRegionUseCase` orchestration, overlay messages during hotkey capture.
- `llh/App/AppShortcutsCoordinator.swift` — registers four `KeyboardShortcuts.onKeyUp` handlers via `AppShortcutHandlers` closures.
- `MainViewModel` — composes `let capture`; retains coordinator; format/study/overlay/editor remain on Main; `configurePostCapture` wires formatting after successful capture.
- `ContentView`, `MenuBarPanelView` — permission UI and capture actions use `viewModel.capture`.
- `RefactorBaselineInventory` — 6 Main + 2 Capture + 4 History + 7 Settings `@Published`; `captureViewModelPublicActions`.

## Boundaries unchanged

- Formatting and word study workflows remain in `MainViewModel`.
- `statusMessage` remains on `MainViewModel`; capture reports via `configureStatusReporting`.
- `KeyboardShortcuts.Recorder` remains in `SettingsView` (UI only).

## Next

Phase 4 PR 4: Study / overlay presentation state.
