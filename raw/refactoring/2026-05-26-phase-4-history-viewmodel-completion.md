# Phase 4 History ViewModel Completion

> Source: llh project refactor session
> Collected: 2026-05-26
> Published: Unknown

## Summary

Second increment of Phase 4 («Split Presentation Into Feature ViewModels»): history and profile UI state moved from `MainViewModel` into `HistoryViewModel`. Sessions sidebar extracted to `Presentation/History/HistoryView.swift`.

## Code changes

- `llh/Presentation/History/HistoryViewModel.swift` — owns 4 former `@Published` history properties; delegates to `ManageHistoryUseCase` and `ManageProfilesUseCase`; load/persist/mutate session API for `MainViewModel` capture/format/study flows.
- `llh/Presentation/History/HistoryView.swift` — profiles picker, entry list, session-reading toggle, create/delete profile sheets.
- `MainViewModel` — composes `let history: HistoryViewModel`; editor/capture/format/study state remains on Main; forwards `objectWillChange`.
- `ContentView` — sidebar uses `HistoryView(viewModel: main.history)`; detail pane reads `viewModel.history.*` for selection and session-reading overview.
- `RefactorBaselineInventory` — split published lists (8 Main + 4 History + 7 Settings).

## Boundaries unchanged

- Hotkey registration remains in `MainViewModel.init`.
- Capture, format, word study, overlay lifecycle remain in `MainViewModel`.
- `statusMessage` remains on `MainViewModel`; history reports via `configureStatusReporting`.

## Next

Phase 4 PR 3: `CaptureViewModel` + `AppShortcutsCoordinator`.
