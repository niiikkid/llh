# Refactoring Phase 8 UI Decomposition

> Sources: llh project, 2026-05-27
> Raw: [Phase 8 UI decomposition completion](../../raw/refactoring/2026-05-27-phase-8-ui-decomposition-completion.md)
> Updated: 2026-05-27

## Overview

Phase 8 («UI Decomposition And State Clarity») **завершена**. `ContentView` разбит на feature views; дублирующая логика отображения форматированного текста централизована в `StructuredFormattedText`; `statusMessage` перенесён с `MainViewModel` на feature ViewModels.

## Структура Presentation

```text
Presentation/
  Main/
    ContentView.swift          — композиция (~45 строк)
    MainChromeView.swift       — заголовок, OCR picker, sessions/settings
    MainWorkspaceView.swift    — sidebar + detail layout
  Capture/
    CapturePermissionBannerView.swift
    CaptureProcessingOverlay.swift
  History/
    HistoryView.swift          (Phase 4)
    SessionReadingOverviewView.swift
    TranslationDetailPanelView.swift
  Editor/
    TranslationEditorView.swift
    FormattedTranslationContentView.swift
    FormattedTranslationBlockView.swift
  Study/
    StudyAssistantView.swift
    WordStudyEntriesView.swift
  Settings/
    SettingsView.swift         (Phase 4)
  Shared/
    PanelGroupBoxStyle.swift
    CenteredContentContainer.swift
    ViewState.swift            — LoadingState, AlertState, ViewState
```

## Domain: отображение форматированного текста

`StructuredFormattedText` (убрано дублирование из бывшего `ContentView`):

| API | Назначение |
|-----|------------|
| `usesPinyinAsPrimary(learningLanguage:)` | Китайский всегда; авто — при непустом пиньинь |
| `primaryDisplayLine(learningLanguage:)` | Основная строка detail/overlay |
| `showsSourceCaptionAbovePrimary(learningLanguage:)` | Показ `cleanedText` над primary |

Список сессий по-прежнему использует `sessionListSourceDisplay(learningLanguage:)`.

## Status messages

| ViewModel | `statusMessage` | UI consumer |
|-----------|-----------------|-------------|
| `CaptureViewModel` | idle: shortcut hint | `MenuBarPanelView` |
| `SettingsViewModel` | OpenAI/OCR feedback | (settings sheet; future banner) |
| `HistoryViewModel` | load/save/profile actions | — |
| `EditorViewModel` | format workflow | — |
| `StudyViewModel` | word study workflow | — |

`MainViewModel` больше не имеет `@Published` и не агрегирует status callbacks.

## MainViewModel после Phase 8

- Композиция feature VMs + overlay shortcuts
- ~130 строк, без `@Published`
- Study UI вызывает `StudyViewModel` напрямую (прокси с Main удалены)

## Критерии выхода (roadmap)

| Критерий | Статус |
|----------|--------|
| Split `ContentView` into feature views | ✅ |
| Settings/history/study/capture views in Presentation | ✅ |
| Feature-specific status (не общий `MainViewModel.statusMessage`) | ✅ |
| `ViewState` / `LoadingState` / `AlertState` types | ✅ `Presentation/Shared/ViewState.swift` |
| Consolidated pinyin/primary display logic | ✅ `StructuredFormattedText` |
| Main UI files smaller and feature-oriented | ✅ |

## Следующий шаг

**Phase 9** — testing strategy (use case/repository/migration coverage alignment). См. [roadmap](project-refactoring-roadmap.md).

## See Also

- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь `@Published` после Phase 8
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — `StructuredFormattedText` display helpers
- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md) — feature ViewModels (Phase 4) + views (Phase 8)
- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md)
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — архивный snapshot; Phase 8 exit criteria в roadmap §Phase 8
