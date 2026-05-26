# Phase 4 Study and Overlay Extraction Completion

> Source: llh project refactor session
> Collected: 2026-05-26
> Published: Unknown

## Summary

Fourth increment of Phase 4: word study presentation state moved to `StudyViewModel`; translation overlay lifecycle and post-format hotkey overlay coordination moved to `TranslationOverlayCoordinator`.

## Code changes

- `llh/Presentation/Study/StudyViewModel.swift` — `studyMaterials`, `LoadWordStudyUseCase` orchestration, retry and status computed properties.
- `llh/Presentation/Overlay/TranslationOverlayCoordinator.swift` — awaiting-format entry ID, close/toggle last translation, format result overlay handling.
- `MainViewModel` — composes `let study` and private `overlay`; format/editor state remains on Main; thin proxies for overlay shortcuts and study retry.
- `ContentView` — study UI reads `viewModel.study.studyMaterials`.
- `RefactorBaselineInventory` — 5 Main + 1 Study + 2 Capture + 4 History + 7 Settings `@Published`; overlay and study action inventories.

## Boundaries unchanged

- Formatting workflow (`FormatCapturedTextUseCase`) remains in `MainViewModel`.
- Editor fields (`recognizedText`, `formattedRecognizedText`, `capturedImage`) remain on Main.
- Hotkey capture-time overlay messages remain in `CaptureViewModel` via `TranslationOverlayService`.
- `statusMessage` remains on `MainViewModel`.

## Next

Phase 4 PR 5: extract editor/format presentation or minimize `MainViewModel`.
