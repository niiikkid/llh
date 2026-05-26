# Phase 4 editor ViewModel completion

> Source: llh project implementation
> Collected: 2026-05-26
> Published: Unknown

## Summary

Phase 4 increment 5: editor and format presentation extracted from `MainViewModel` into `Presentation/Editor/EditorViewModel.swift`. No user-facing behavior changes.

## Changes

- `EditorViewModel`: `recognizedText`, `formattedRecognizedText`, `capturedImage`, `isFormattingRecognizedText`; `FormatCapturedTextUseCase`; selection sync; post-capture format; overlay format handlers.
- `MainViewModel`: ~150 lines; only `statusMessage` `@Published`; composition facade with overlay shortcuts and study retry proxies for `ContentView`.
- `ContentView`: reads editor/history/study state from feature ViewModels.
- `RefactorBaselineInventory`: Main 1 `@Published`; Editor 4 `@Published`; editor public actions.

## Metrics

| Metric | Before | After |
|--------|--------|-------|
| `@Published` on Main | 5 | 1 |
| `@Published` on Editor | — | 4 |
| Lines `MainViewModel` | ~307 | ~150 |
