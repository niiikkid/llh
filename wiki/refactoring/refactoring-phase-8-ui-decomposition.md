# Refactoring Phase 8 UI Decomposition

> Sources: llh project, 2026-05-27
> Raw: [Phase 8 UI decomposition completion](../../raw/refactoring/2026-05-27-phase-8-ui-decomposition-completion.md)
> Updated: 2026-05-27

**Post–Phase 8 (v0.2):** [Increment 1 UI polish](v0-2-product-plan.md#increment-1-quick-ui-polish) updated `MainChromeView`, `HistoryView`, `MenuBarPanelView`, `CapturePermissionBannerView`; added `AppDisplayStrings` and `SessionLanguageBadge`. [Increment 2 session navigation](v0-2-product-plan.md#increment-2-main-window-and-session-navigation) added `SessionsListView`, `AppMainRoute`, route-based `ContentView`; `HistoryView` is translations-only sidebar; `SessionLanguageBadge` in `Presentation/Shared/`. [Increment 3 settings page](v0-2-product-plan.md#increment-3-settings-as-a-page) relaid out `SettingsView` with `PanelGroupBoxStyle` sections and aligned rows; removed sheet-era fixed size and «Закрыть». [Increment 4 translation result state](v0-2-product-plan.md#increment-4-translation-result-state) unified `TranslationEditorView` on `FormattingStatus` (no raw/formatted tabs; loading/failed banners). [Increment 5 words and grammar tabs](v0-2-product-plan.md#increment-5-words-and-grammar-tabs) added segmented `StudyAssistantView`, `GrammarExplanationView`, `LoadGrammarStudyUseCase`. [Increment 6 session-level automation](v0-2-product-plan.md#increment-6-session-level-automation) added per-session automation toggles on `SessionsListView` and hints in `StudyAssistantView`. [Increment 7 compact overlay closing](v0-2-product-plan.md#increment-7-compact-overlay-closing) — close button + Escape in `TranslationOverlayService` (`CompactOverlayView`); settings copy for manual dismiss while processing. [Increment 10 single main window](v0-2-product-plan.md#increment-10-single-main-window-behavior) added `MainWindowActivator` / `MainWindowIdentityView`; `MenuBarPanelView` activates existing window instead of duplicating.

## Overview

Phase 8 («UI Decomposition And State Clarity») **завершена**. `ContentView` разбит на feature views; дублирующая логика отображения форматированного текста централизована в `StructuredFormattedText`; `statusMessage` перенесён с `MainViewModel` на feature ViewModels.

## Структура Presentation

```text
App/
  MainWindowActivator.swift    — v0.2 inc. 10: single main window activation
Presentation/
  Main/
    AppMainRoute.swift         — v0.2 inc. 2: sessions / workspace / settings
    ContentView.swift          — маршруты; MainWindowIdentityView (v0.2 inc. 10)
    MainChromeView.swift       — навигация, OCR picker, sidebar toggle (v0.2 inc. 1–2)
    MainWorkspaceView.swift    — sidebar переводов + detail
  Capture/
    CapturePermissionBannerView.swift
    CaptureProcessingOverlay.swift
  History/
    HistoryView.swift          — translations sidebar (v0.2 inc. 2)
    SessionsListView.swift     — session CRUD + automation UI (v0.2 inc. 2, 6)
    SessionReadingOverviewView.swift
    TranslationDetailPanelView.swift
  Editor/
    TranslationEditorView.swift
    TranslationResultPresentation.swift  — v0.2 inc. 4
    FormattedTranslationContentView.swift
    FormattedTranslationBlockView.swift
  Study/
    StudyAssistantView.swift   — v0.2 inc. 5: words / grammar tabs
    StudyLearningTab.swift
    GrammarExplanationView.swift
    WordStudyEntriesView.swift
  Settings/
    SettingsView.swift         — full-page tabs + GroupBox sections (v0.2 inc. 3; private row helpers in-file)
  Shared/
    AppDisplayStrings.swift    — product name (v0.2 inc. 1)
    SessionLanguageBadge.swift — language badge (v0.2 inc. 2)
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
| `SettingsViewModel` | OpenAI/OCR feedback | `SettingsView` via `AppMainRoute.settings` (v0.2 inc. 2–3) |
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

**Phases 9–10 завершены** — [Phase 9](refactoring-phase-9-testing-strategy.md), [Phase 10](refactoring-phase-10-cleanup.md).

## See Also

- [Refactoring Phase 10 Cleanup](refactoring-phase-10-cleanup.md) — overlay display dedup (`overlayPrimaryText`)
- [Refactoring Phase 9 Testing Strategy](refactoring-phase-9-testing-strategy.md) — `CaptureViewModel` / UI tests после decomposition
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь `@Published` после Phase 8
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — `StructuredFormattedText` display helpers
- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md) — feature ViewModels (Phase 4) + views (Phase 8)
- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md)
- [v0.2 Product Plan](v0-2-product-plan.md) — v0.2 Increments 1–7 and 10 on Presentation shell
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — архивный snapshot; Phase 8 exit criteria в roadmap §Phase 8
