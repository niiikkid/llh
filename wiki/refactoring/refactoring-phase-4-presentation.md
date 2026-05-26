# Refactoring Phase 4 Presentation

> Sources: llh project, 2026-05-26
> Raw: [Phase 4 settings ViewModel completion](../../raw/refactoring/2026-05-26-phase-4-settings-viewmodel-completion.md); [Phase 4 history ViewModel completion](../../raw/refactoring/2026-05-26-phase-4-history-viewmodel-completion.md); [Phase 4 capture ViewModel completion](../../raw/refactoring/2026-05-26-phase-4-capture-viewmodel-completion.md); [Phase 4 study and overlay completion](../../raw/refactoring/2026-05-26-phase-4-study-overlay-completion.md); [Phase 4 editor ViewModel completion](../../raw/refactoring/2026-05-26-phase-4-editor-viewmodel-completion.md)
> Updated: 2026-05-27

## Overview

Phase 4 («Split Presentation Into Feature ViewModels») **завершена** по критериям roadmap. Слой `Presentation/` содержит feature ViewModels; `MainViewModel` — композиционный фасад. **Phase 8** завершила decomposition SwiftUI views — см. [Phase 8](refactoring-phase-8-ui-decomposition.md). Phase 5 подключила SQLite persistence через `HistoryRepositoryBootstrap` без изменения feature VMs — см. [Phase 5](refactoring-phase-5-sqlite-persistence.md).

Целевая структура (roadmap):

```text
Presentation/
  Main/ContentView.swift
  Settings/SettingsView.swift + SettingsViewModel.swift
  History/HistoryView.swift + HistoryViewModel.swift
  Capture/CaptureViewModel.swift
  Editor/EditorViewModel.swift
  Study/StudyViewModel.swift
  Overlay/TranslationOverlayCoordinator.swift
  MenuBar/…
App/
  AppDependencyContainer.swift
  AppShortcutsCoordinator.swift
```

Композиция `MainViewModel` (inc. 5):

```text
MainViewModel
  ├── settings: SettingsViewModel
  ├── history: HistoryViewModel
  ├── capture: CaptureViewModel
  ├── study: StudyViewModel
  ├── editor: EditorViewModel
  ├── overlay: TranslationOverlayCoordinator (private)
  └── shortcutsCoordinator (private, удерживается в init)
```

## Инкремент 1 — Settings (завершён)

| Файл | Строк (≈) | Назначение |
|------|-----------|------------|
| `Presentation/Settings/SettingsViewModel.swift` | 147 | Состояние и действия настроек |
| `Presentation/Settings/SettingsView.swift` | 221 | Sheet: вкладки «Общие» и «OpenAI» |
| `MainViewModel.swift` | — | Фасад: `let settings` |

7 `@Published` на Settings; OCR hotkey toast в Settings VM.

## Инкремент 2 — History (завершён)

| Файл | Строк (≈) | Назначение |
|------|-----------|------------|
| `Presentation/History/HistoryViewModel.swift` | 253 | Профили, выбор записи, load/persist/mutate session |
| `Presentation/History/HistoryView.swift` | 188 | Sidebar: сессии, список переводов, create/delete profile |
| `MainViewModel.swift` | 509 | Фасад: `let history`; capture/format/study/editor |
| `ContentView.swift` | 513 | Sidebar через `HistoryView`; detail — editor + session reading |

### Состояние в HistoryViewModel (4 `@Published`)

| Свойство | Назначение |
|----------|------------|
| `profiles` | Все learning-профили |
| `selectedProfileID` | Активная сессия |
| `selectedEntryID` | Выбранный перевод |
| `showsSessionReadingOverview` | Режим «весь текст сессии» |

### Публичные действия HistoryViewModel

`deleteSelectedEntry`, `selectEntry`, `createProfile`, `selectProfile`, `deleteSelectedProfile`, `toggleSessionReadingOverview`, `copySessionReadingOverviewToPasteboard`, `formattedDate`.

API для Main: `session`, `applySession`, `persist`, `loadFromDisk`, `mutateEntry`, `insertEntry`, `updateSelectedEntryText`, индексы `selectedProfileIndex` / `selectedEntryIndex`.

### Границы и DI

- Domain: `ManageHistoryUseCase`, `ManageProfilesUseCase` (без изменений с Phase 3).
- `statusMessage` на `MainViewModel`; history — `configureStatusReporting`.
- Синхронизация editor при смене выбора: `configureSelectionSync` → `EditorViewModel.syncSelectionFromHistory` (после inc. 5).
- `createProfile` → `configureNewProfileLanguagePersistence` → `settings.setDefaultNewProfileLearningLanguage`.
- Capture/format/word study читают `history.profiles`, `history.session`, `history.mutateEntry`, `history.persist`.

### MainViewModel после инкремента 2

| Метрика | Phase 4 inc. 1 | Phase 4 inc. 2 |
|---------|----------------|----------------|
| `@Published` на Main | 12 | **8** |
| `@Published` на History | — | **4** |
| `@Published` на Settings | 7 | **7** |
| Строк `MainViewModel` | ~685 | **~509** |
| Строк `ContentView` | ~682 | **~513** |

History/profiles/session-reading методы удалены с `MainViewModel`; computed `currentProfileLearningLanguage` / `currentProfileSupportsWordStudy` — тонкие прокси к `history`.

### Тесты и инвентарь

- `RefactorBaselineInventory`: 8 + 4 + 7 `@Published`; `historyViewModelPublicActions`.
- `RefactorBaselineTests`: locks 8 + 4 + 7.
- `Phase1RepositoryTests`: `viewModel.history.profiles`.
- `llhTests`: `HistoryViewModel.plainTextForSessionReadingCopy`.

Поведение для пользователя не менялось.

## Инкремент 3 — Capture + shortcuts (завершён)

| Файл | Строк (≈) | Назначение |
|------|-----------|------------|
| `Presentation/Capture/CaptureViewModel.swift` | ~200 | Захват, permission status/request, hotkey cancel (Phase 7) |
| `App/AppShortcutsCoordinator.swift` | 42 | Регистрация global shortcuts через closures |
| `MainViewModel.swift` | 439 | Фасад: `let capture`; format/study/overlay/editor |

### Состояние в CaptureViewModel (3 `@Published`, Phase 7)

| Свойство | Назначение |
|----------|------------|
| `isProcessing` | Идёт выделение области / OCR |
| `showPermissionHelp` | Нужен Screen Recording |
| `permissionStatus` | `.authorized` / `.denied` (Phase 7) |

### Публичные действия CaptureViewModel

`triggerCapture`, `triggerCaptureFromHotkey`, `refreshPermissionState`, `requestScreenRecordingAccess`, `openSystemSettings`, `cancelActiveCapture` (Phase 7: повторный hotkey во время захвата).

API для Main: `configureStatusReporting`, `configurePrepareForInterfaceCapture`, `configureSelectionSync`, `configureCapturePreviewWithoutEntry`, `configureOverlayAwaitingFormatReset`, `configurePostCapture`.

`CaptureViewModel` получает `permissionService` и `captureRegionUseCase` из `AppDependencyContainer`; читает OCR/API key из `settings`, пишет в историю через `history.insertEntry` / `persist`.

### AppShortcutsCoordinator

Четыре hotkey → `AppShortcutHandlers` (capture, switch OCR, close overlay, toggle last translation). Main передаёт weak-замыкания на `capture`, `settings`, overlay-методы.

### MainViewModel после инкремента 3

| Метрика | inc. 2 | inc. 3 |
|---------|--------|--------|
| `@Published` на Main | 8 | **6** |
| `@Published` на Capture | — | **2** |
| `@Published` на History | 4 | **4** |
| `@Published` на Settings | 7 | **7** |
| Строк `MainViewModel` | ~509 | **~439** |

Format/study/overlay и editor state остаются на Main (до inc. 5); после capture Main запускает format через `configurePostCapture`.

### Тесты и инвентарь

- `RefactorBaselineInventory`: 6 + 2 + 4 + 7 `@Published`; `captureViewModelPublicActions`.
- `RefactorBaselineTests`: locks 6 + 2 + 4 + 7.

Поведение для пользователя не менялось.

## Инкремент 4 — Study + overlay (завершён)

| Файл | Строк (≈) | Назначение |
|------|-----------|------------|
| `Presentation/Study/StudyViewModel.swift` | 151 | Word study materials, `LoadWordStudyUseCase`, retry |
| `Presentation/Overlay/TranslationOverlayCoordinator.swift` | 92 | Overlay после format, toggle last translation, awaiting entry ID |
| `MainViewModel.swift` | 307 | Фасад: `let study`; format/editor на Main |
| `ContentView.swift` | 513 | Study block читает `viewModel.study.studyMaterials` |

### Состояние в StudyViewModel (1 `@Published`)

| Свойство | Назначение |
|----------|------------|
| `studyMaterials` | Word study payload и status для выбранной записи |

### TranslationOverlayCoordinator

Не `ObservableObject`. Методы: `close`, `toggleLastTranslation`, `clearAwaitingFormattedEntry`, `markEntryAwaitingFormattedResult`, `handleFormattingPreflightFailure` / `Success` / `Failure`.

Main сохраняет публичные прокси `closeTranslationOverlay`, `toggleLastTranslationOverlay` для shortcuts. Capture сбрасывает awaiting через `configureOverlayAwaitingFormatReset` → `overlay.clearAwaitingFormattedEntry()`.

### MainViewModel после инкремента 4

| Метрика | inc. 3 | inc. 4 |
|---------|--------|--------|
| `@Published` на Main | 6 | **5** |
| `@Published` на Study | — | **1** |
| `@Published` на Capture | 2 | **2** |
| `@Published` на History | 4 | **4** |
| `@Published` на Settings | 7 | **7** |
| Строк `MainViewModel` | ~439 | **~307** |

На Main остаются: `recognizedText`, `formattedRecognizedText`, `capturedImage`, `statusMessage`, `isFormattingRecognizedText`, `FormatCapturedTextUseCase`.

### Тесты и инвентарь

- `RefactorBaselineInventory`: 5 + 1 + 2 + 4 + 7 `@Published`; `studyViewModelPublicActions`, `translationOverlayCoordinatorPublicActions`.
- `RefactorBaselineTests`: locks 5 + 1 + 2 + 4 + 7.

Поведение для пользователя не менялось.

## Инкремент 5 — Editor/format (завершён)

| Файл | Строк (≈) | Назначение |
|------|-----------|------------|
| `Presentation/Editor/EditorViewModel.swift` | 198 | Editor state, `FormatCapturedTextUseCase`, selection sync, post-capture format |
| `MainViewModel.swift` | 157 | Фасад: `statusMessage`, overlay shortcuts, study retry proxies |
| `ContentView.swift` | 513 | Editor UI через `viewModel.editor`; язык профиля — `viewModel.history` |

### Состояние в EditorViewModel (4 `@Published`)

| Свойство | Назначение |
|----------|------------|
| `recognizedText` | Сырой текст выбранной записи |
| `formattedRecognizedText` | Форматированный перевод для UI |
| `capturedImage` | Превью скриншота in-memory |
| `isFormattingRecognizedText` | Идёт запрос format в OpenAI |

### Публичные действия EditorViewModel

`updateSelectedText`, `retryFormattingForSelectedEntry`, `syncSelectionFromHistory`, `applyCapturePreviewWithoutEntry`, `handlePostCapture`.

### MainViewModel после инкремента 5

| Метрика | inc. 4 | inc. 5 |
|---------|--------|--------|
| `@Published` на Main | 5 | **1** |
| `@Published` на Editor | — | **4** |
| `@Published` на Study | 1 | **1** |
| `@Published` на Capture | 2 | **2** |
| `@Published` на History | 4 | **4** |
| `@Published` на Settings | 7 | **7** |
| Строк `MainViewModel` | ~307 | **~157** |

Итого `@Published`: **1 + 4 + 1 + 2 + 4 + 7 = 19** (как в Phase 0, распределены по feature VMs).

### Тесты и инвентарь

- `RefactorBaselineInventory`: `editorViewModelPublishedPropertyNames`, `editorViewModelPublicActions`.
- `RefactorBaselineTests`: locks 1 + 4 + 1 + 2 + 4 + 7.

Поведение для пользователя не менялось.

## Критерии выхода Phase 4 (roadmap)

| Критерий | Статус |
|----------|--------|
| `SettingsView` + `SettingsViewModel` | выполнено |
| `HistoryView` + `HistoryViewModel` | выполнено |
| `CaptureViewModel` + `AppShortcutsCoordinator` | выполнено |
| `StudyViewModel` + overlay coordinator | выполнено |
| `EditorViewModel` (format/editor state) | выполнено |
| `MainViewModel` минимизирован | выполнено |
| `ContentView` разбит по feature views | выполнено (Phase 8) |
| Feature ViewModels владеют своим UI state | выполнено |
| Shortcuts вне feature ViewModels | выполнено |

## Phase 8 (UI decomposition, завершена)

Критерий Phase 4 «ContentView split» закрыт в Phase 8:

- `Presentation/Main/ContentView.swift` — тонкая композиция (~45 строк)
- Feature views: `MainChromeView`, `MainWorkspaceView`, `TranslationDetailPanelView`, `TranslationEditorView`, `StudyAssistantView`, `SessionReadingOverviewView`, `CapturePermissionBannerView`
- `statusMessage` перенесён с Main на feature ViewModels; Main без `@Published` (~129 строк)

## Следующий шаг

**Phases 5–10 завершены** — tests в [Phase 9](refactoring-phase-9-testing-strategy.md); cleanup в [Phase 10](refactoring-phase-10-cleanup.md).

## See Also

- [Refactoring Phase 10 Cleanup](refactoring-phase-10-cleanup.md) — dead code removal, `overlayPrimaryText`
- [Refactoring Phase 9 Testing Strategy](refactoring-phase-9-testing-strategy.md) — presentation-layer UI smoke
- [Refactoring Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md) — завершение split ContentView (завершена)
- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md) — CaptureViewModel permission/cancel polish (завершена)
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md) — Phase 6 завершена (HTTP, models, OCR, translation/study, settings/keychain, timeout)
- [Refactoring Phase 5 SQLite Persistence](refactoring-phase-5-sqlite-persistence.md) — GRDB, миграция JSON→SQLite, bootstrap
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — use cases до split presentation
- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md) — контейнер и протоколы под feature VMs
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь поверхности ViewModel
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — архивный полный план
