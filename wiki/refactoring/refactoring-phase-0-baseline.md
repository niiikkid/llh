# Refactoring Phase 0 Baseline

> Sources: llh project, 2026-05-26
> Raw: [Phase 0 baseline completion](../../raw/refactoring/2026-05-26-phase-0-baseline-completion.md)
> Updated: 2026-05-27

## Overview

Phase 0 («Baseline And Safety Net») завершена: зафиксирована поверхность `MainViewModel`, добавлены characterization-тесты и один чистый extract для repair при загрузке истории. `HistoryEntryLoadRepair` по-прежнему применяется при load через `ManageHistoryUseCase` (JSON и SQLite). Phase 1–5 — см. [Phase 5](refactoring-phase-5-sqlite-persistence.md).

## Артефакты в коде

| Файл | Назначение |
|------|------------|
| `llh/RefactorBaseline/RefactorBaselineInventory.swift` | Инвентарь: 1 Main + 4 Editor + 1 Study + 2 Capture + 4 History + 7 Settings (Phase 4), actions по buckets, триггеры `persistHistory`, карта OpenAI, UI-потребители |
| `llh/RefactorBaseline/HistoryEntryLoadRepair.swift` | Pure repair: `processing` → `failed` после прерванной сессии; очистка пустых formatted/study payloads |
| `llhTests/RefactorBaselineTests.swift` | Тесты-предохранители и inventory locks |

`HistoryViewModel.loadFromDisk()` → `ManageHistoryUseCase.loadSession()` с repair через `HistoryEntryLoadRepair.repairProfile` (раньше inline в `MainViewModel.loadHistory`).

## Инвентарь MainViewModel

### Состояние UI

**Исходный снимок Phase 0:** 19 `@Published` на одном `MainViewModel`.

**После Phase 4 inc. 5:** 1 на `MainViewModel` + 4 на `EditorViewModel` + 1 на `StudyViewModel` + 2 на `CaptureViewModel` + 4 на `HistoryViewModel` + 7 на `SettingsViewModel`.

**После Phase 8:** 0 на `MainViewModel` + 5 на `EditorViewModel` + 2 на `StudyViewModel` + 4 на `CaptureViewModel` + 5 на `HistoryViewModel` + 8 на `SettingsViewModel` (`RefactorBaselineInventory`). На каждом feature VM добавлен `statusMessage`; menu bar читает `capture.statusMessage`.

Editor: `recognizedText`, `formattedRecognizedText`, `capturedImage`, `isFormattingRecognizedText`, `statusMessage`.

Study VM: `studyMaterials`, `statusMessage`.

Capture VM: `isProcessing`, `showPermissionHelp`, `permissionStatus`, `statusMessage`.

History VM: `profiles`, `selectedProfileID`, `selectedEntryID`, `showsSessionReadingOverview`, `statusMessage`.

Settings VM: OpenAI models/token, OCR engine, default profile language, overlay timing, `isLoadingOpenAIModels`, `statusMessage`.

### Feature buckets (публичные действия)

- **Capture / permissions:** на `CaptureViewModel` (`triggerCapture`, `refreshPermissionState`, `openSystemSettings`)
- **OCR / settings UI:** перенесены в `SettingsViewModel` (`selectOCREngine`, `switchToNextOCREngine`, token/model/overlay setters)
- **Formatting:** `retryFormattingForSelectedEntry` (на `EditorViewModel`); длительность overlay — `SettingsViewModel.calculatedTranslationOverlayDuration`
- **History:** `updateSelectedText` (на `EditorViewModel`; координирует editor + `history.updateSelectedEntryText`)
- **Profiles / session list:** на `HistoryViewModel` (`createProfile`, `selectProfile`, `deleteSelectedProfile`, `deleteSelectedEntry`, `selectEntry`, session reading)
- **Overlay:** `TranslationOverlayCoordinator` (`close`, `toggleLastTranslation`, format-result handlers); Main — прокси `closeTranslationOverlay`, `toggleLastTranslationOverlay` для shortcuts
- **Study (words):** `StudyViewModel.retryStudyAssistantDataForSelectedEntry` (Phase 8: UI вызывает Study VM напрямую, без прокси Main)
- **Session reading:** на `HistoryViewModel` (`toggleSessionReadingOverview`, `copySessionReadingOverviewToPasteboard`, `plainTextForSessionReadingCopy`)

**Shortcuts:** `AppShortcutsCoordinator` в `App/`; handlers вызывают capture/settings/overlay на Main (не public API на feature ViewModels).

### Когда пишется история (`persist` / `history.persist()`)

11 точек (инвентарь Phase 0): удаление/создание профиля, правка текста, вставка после capture, старт/успех/ошибка форматирования, старт/успех/ошибка word study. После Phase 4 inc. 2: profile/entry CRUD — `HistoryViewModel.persist()`; правка текста — `EditorViewModel` → `history.updateSelectedEntryText` + `persist`. После inc. 3: вставка после capture — `CaptureViewModel` → `history.insertEntry` + `persist`. После inc. 4: word study — `StudyViewModel` через `history.mutateEntry` + `persist()`. После inc. 5: format — `EditorViewModel` через `FormatCapturedTextUseCase`.

### OpenAI

Все шесть методов `OpenAIServing` существуют в `OpenAIService`.

**Исходный инвентарь Phase 0:** из `MainViewModel` напрямую вызывались models, AI OCR, format, words study.

**После Phase 3:** workflows за use cases; `ManageOpenAISettingsUseCase` вызывался из `MainViewModel`.

**После Phase 4 inc. 1:** UI настроек и 7 `@Published` — в `SettingsViewModel` → `ManageOpenAISettingsUseCase`. `MainViewModel` координирует capture/format/study и читает `settings.*` для конфигурации.

**После Phase 4 inc. 2:** история/профили и 4 `@Published` — в `HistoryViewModel` → `ManageHistoryUseCase` / `ManageProfilesUseCase`. `MainViewModel` (~509 строк) — editor, capture, format, study, overlay; `history.*` для session state.

**После Phase 4 inc. 3:** capture и 2 `@Published` — в `CaptureViewModel` → `CaptureRegionUseCase`. `MainViewModel` (~439 строк) — editor, format, study, overlay; `capture.*` для permission/processing UI; `AppShortcutsCoordinator` для hotkeys.

**После Phase 4 inc. 4:** study и 1 `@Published` — в `StudyViewModel` → `LoadWordStudyUseCase`. Overlay lifecycle — `TranslationOverlayCoordinator`.

**После Phase 4 inc. 5:** editor/format и 4 `@Published` — в `EditorViewModel` → `FormatCapturedTextUseCase`. `MainViewModel` (~157 строк) — фасад: `statusMessage`, shortcuts, overlay proxies.

**После Phase 8:** `MainViewModel` (~129 строк) — композиция feature VMs + overlay shortcuts; без `@Published`. UI decomposition — см. [Phase 8](refactoring-phase-8-ui-decomposition.md).

**Не подключены к UI:**

- `buildPhrasesStudyData`
- `buildGrammarStudyData`

Промпты: `OpenAIPromptBuilder` (Phase 2). HTTP: `OpenAIHTTPClient` (PR 2 + PR 6 timeout/cancellation). Models: `OpenAIModelsService` (PR 3). AI OCR: `OpenAIOCRService` (PR 4). Format/study: `OpenAITranslationService`, `OpenAIStudyService` (PR 5). Settings/keychain: `OpenAISettingsStore`, `KeychainOpenAITokenStore` в `Data/OpenAI/` (PR 6). `OpenAIService` — чистый фасад `OpenAIServing`.

**Phase 6 завершена:** transport + models + AI OCR + translation/study + settings/keychain split; `OpenAIOCRServing` — граница для `RecognizeTextUseCase`; 429 → `rateLimited`, timeout/cancellation в HTTP client; endpoint без изменений (Responses API отложен).

### UI зависимости

`llhApp` владеет `StateObject` `MainViewModel`; `Presentation/Main/ContentView` и `MenuBarPanelView` наблюдают Main. Композиция UI: `MainChromeView`, `MainWorkspaceView`, `HistoryView`, `TranslationDetailPanelView`, `TranslationEditorView`, `StudyAssistantView`, `CapturePermissionBannerView`. Sidebar — `HistoryView(main.history)`; settings sheet — `SettingsView(main.settings)`; menu bar status — `main.capture.statusMessage`; capture — `main.capture.triggerCapture()`.

## Покрытие тестами (Phase 0)

Новые тесты в `RefactorBaselineTests` закрывают пункты roadmap Phase 0:

- Multi-profile JSON roundtrip
- Legacy формат `history.json` как массив записей (не snapshot)
- Default profile всегда на индексе 0 после load
- Repair прерванного formatting / word study
- Persistence OCR engine (`OpenAISettingsStore.selectedOCREngineRawValue`)
- `OpenAIPromptBuilder.formattingRules` / `wordsAnalysisPrompt` / `OpenAIServiceError` descriptions (вкл. `rateLimited`, `timeout`, `cancelled`)

Ранее существующие тесты в `llhTests.swift` (overlay timing, legacy profile decode, single-profile persistence, prompt variants) остаются дополнительной сеткой.

## Критерии выхода Phase 0

| Критерий | Статус |
|----------|--------|
| Инвентарь в коде/тестах | выполнено |
| Regression coverage persistence/settings/prompts | выполнено |
| Без изменения продуктового поведения | выполнено |

## See Also

- [Refactoring Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md) — Phase 8 завершена: split ContentView, per-VM statusMessage
- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md) — Phase 7 завершена: `OCRResult`, Infrastructure OCR/capture, cancellation
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md) — Phase 6 завершена: HTTP, models, OCR, translation/study, settings/keychain, timeout
- [Refactoring Phase 5 SQLite Persistence](refactoring-phase-5-sqlite-persistence.md) — persistence после baseline
- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md) — Phase 4 завершена
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — Phase 3 завершена
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — модели в `Domain/Models`
- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md) — завершённый Phase 1
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — полный пофазный план (архивный snapshot на 2026-05-26)
