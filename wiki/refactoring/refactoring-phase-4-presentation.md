# Refactoring Phase 4 Presentation

> Sources: llh project, 2026-05-26
> Raw: [Phase 4 settings ViewModel completion](../../raw/refactoring/2026-05-26-phase-4-settings-viewmodel-completion.md)
> Updated: 2026-05-26

## Overview

Phase 4 («Split Presentation Into Feature ViewModels») **в процессе**. Цель — слой `Presentation/` с feature ViewModels, разбиение `ContentView`, `MainViewModel` как композиционный фасад (или удаление на финальном PR).

Целевая структура (roadmap):

```text
Presentation/
  Main/ContentView.swift
  Settings/SettingsView.swift + SettingsViewModel.swift
  History/…
  Capture/…
  Study/…
  MenuBar/…
```

## Инкремент 1 — Settings (завершён)

| Файл | Строк (≈) | Назначение |
|------|-----------|------------|
| `Presentation/Settings/SettingsViewModel.swift` | 147 | Состояние и действия настроек |
| `Presentation/Settings/SettingsView.swift` | 221 | Sheet: вкладки «Общие» (shortcuts + overlay timing) и «OpenAI» |
| `MainViewModel.swift` | 685 | Фасад: `let settings`, подписка `objectWillChange` |
| `ContentView.swift` | 682 | Toolbar OCR + sheet через `viewModel.settings` |

### Состояние в SettingsViewModel (7 `@Published`)

| Свойство | Назначение |
|----------|------------|
| `availableOpenAIModels` | Кэш списка моделей |
| `selectedOpenAIModelID` | Выбранная модель |
| `selectedOCREngine` | local / AI |
| `defaultNewProfileLearningLanguage` | Язык по умолчанию для новых профилей |
| `translationOverlayMinimumDuration` | Минимум показа compact overlay |
| `translationOverlaySecondsPerWord` | Секунд на слово в формуле длительности |
| `isLoadingOpenAIModels` | Validate / refresh token |

### Публичные действия SettingsViewModel

`validateAndSaveOpenAIToken`, `refreshOpenAIModels`, `deleteOpenAIToken`, `selectOpenAIModel`, `selectOCREngine`, `switchToNextOCREngine`, `setDefaultNewProfileLearningLanguage`, `setTranslationOverlayMinimumDuration`, `setTranslationOverlaySecondsPerWord`, `currentAPIKey()`, `calculatedTranslationOverlayDuration(for:)`.

### Границы и DI

- Domain: `ManageOpenAISettingsUseCase` (без изменений с Phase 3).
- `statusMessage` остаётся в `MainViewModel`; settings вызывает `configureStatusReporting { … }` после init.
- OCR toast при hotkey switch: `TranslationOverlayService` внутри `SettingsViewModel` (проверка `!NSApp.isActive`).
- **Hotkey registration** — по-прежнему в `MainViewModel.init`; handler OCR вызывает `settings.switchToNextOCREngine(triggeredByHotkey: true)` (PR 3: `AppShortcutsCoordinator`).
- Capture / format / word study в `MainViewModel` читают `settings.selectedOCREngine`, `settings.currentAPIKey()`, `settings.selectedOpenAIModelID`, `settings.calculatedTranslationOverlayDuration`.

### MainViewModel после инкремента 1

| Метрика | Phase 3 (конец) | Phase 4 inc. 1 |
|---------|-----------------|----------------|
| `@Published` на Main | 19 | **12** |
| `@Published` на Settings | — | **7** |
| Строк `MainViewModel` | ~783 | **~685** |

Settings-related методы удалены с `MainViewModel`; `createProfile` вызывает `settings.setDefaultNewProfileLearningLanguage`.

### Тесты и инвентарь

- `RefactorBaselineInventory`: `mainViewModelPublishedPropertyNames` (12) + `settingsViewModelPublishedPropertyNames` (7); buckets `.ocr` / `.settings` на Main пустые; действия settings — в `settingsViewModelPublicActions`.
- `RefactorBaselineTests`: locks 12 + 7.
- `Phase1RepositoryTests`: `viewModel.settings.hasOpenAIToken`.

Поведение для пользователя не менялось.

## Следующие инкременты (roadmap PR 2–5)

| PR | Содержание |
|----|------------|
| 2 | `HistoryViewModel` + `HistoryView` (profiles, entries, sidebar) |
| 3 | `CaptureViewModel` + `AppShortcutsCoordinator` |
| 4 | Study / overlay presentation state |
| 5 | Убрать или минимизировать `MainViewModel` |

## Критерии выхода Phase 4 (roadmap)

| Критерий | Статус |
|----------|--------|
| `SettingsView` + `SettingsViewModel` | выполнено |
| `HistoryView` + `HistoryViewModel` | ожидает PR 2 |
| `ContentView` разбит по feature views | частично |
| Feature ViewModels владеют своим UI state | частично (settings) |
| Shortcuts вне feature ViewModels | ожидает PR 3 |

## See Also

- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — use cases до split presentation
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь поверхности ViewModel
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — архивный полный план
