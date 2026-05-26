# Phase 8 UI Decomposition Completion

> Source: llh project implementation
> Collected: 2026-05-27
> Published: 2026-05-27

## Summary

Phase 8 completed: `ContentView` split into feature views under `Presentation/`, shared `PanelGroupBoxStyle`, `FormattedTextDisplay` helpers on `StructuredFormattedText`, per-feature `statusMessage` on ViewModels (removed from `MainViewModel`).

## New presentation files

- `Presentation/Main/ContentView.swift`, `MainChromeView.swift`, `MainWorkspaceView.swift`
- `Presentation/Capture/CapturePermissionBannerView.swift`, `CaptureProcessingOverlay.swift`
- `Presentation/History/SessionReadingOverviewView.swift`, `TranslationDetailPanelView.swift`
- `Presentation/Editor/TranslationEditorView.swift`, `FormattedTranslationContentView.swift`, `FormattedTranslationBlockView.swift`
- `Presentation/Study/StudyAssistantView.swift`, `WordStudyEntriesView.swift`
- `Presentation/Shared/ViewState.swift`, `PanelGroupBoxStyle.swift`, `CenteredContentContainer.swift`

## Domain

- `StructuredFormattedText`: `primaryDisplayLine`, `showsSourceCaptionAbovePrimary`, `usesPinyinAsPrimary`

## ViewModels

- `statusMessage` on Capture, Settings, History, Study, Editor ViewModels
- `MainViewModel`: no `@Published`; removed study/status proxies
- `MenuBarPanelView`: `capture.statusMessage`

## Removed

- `llh/ContentView.swift` (monolith)

## Tests

- `Phase2DomainModelsTests`: primary display line helpers
- `RefactorBaselineTests`: inventory counts updated

## Next

Phase 9 — testing strategy alignment per roadmap.
