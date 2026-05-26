# Phase 4 Settings ViewModel Completion

> Source: llh project refactor session
> Collected: 2026-05-26
> Published: Unknown

## Summary

First increment of Phase 4 («Split Presentation Into Feature ViewModels»): settings UI state and OpenAI/OCR/overlay timing workflows moved from `MainViewModel` into `SettingsViewModel`. Settings sheet extracted to `Presentation/Settings/SettingsView.swift`.

## Code changes

- `llh/Presentation/Settings/SettingsViewModel.swift` — owns 7 former `@Published` settings properties; delegates to `ManageOpenAISettingsUseCase`; reports status to `MainViewModel` via `configureStatusReporting`.
- `llh/Presentation/Settings/SettingsView.swift` — `SettingsView`, `GeneralSettingsTab`, `OpenAISettingsTab` (from `ContentView`).
- `MainViewModel` — composes `let settings: SettingsViewModel`; forwards `objectWillChange`; capture/format/study read `settings.*`; shortcuts still call `settings.switchToNextOCREngine` (coordinator extraction deferred to PR 3).
- `ContentView` — OCR toolbar and settings sheet bind to `viewModel.settings`.
- `RefactorBaselineInventory` — split published property lists (12 Main + 7 Settings).

## Boundaries unchanged

- Hotkey registration remains in `MainViewModel.init`.
- History, capture orchestration, overlay lifecycle (except OCR switch toast) remain in `MainViewModel`.

## Next

Phase 4 PR 2: `HistoryViewModel` + `HistoryView`.
