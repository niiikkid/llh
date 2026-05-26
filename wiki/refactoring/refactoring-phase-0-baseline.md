# Refactoring Phase 0 Baseline

> Sources: llh project, 2026-05-26
> Raw: [Phase 0 baseline completion](../../raw/refactoring/2026-05-26-phase-0-baseline-completion.md)
> Updated: 2026-05-26

## Overview

Phase 0 («Baseline And Safety Net») завершена: зафиксирована поверхность `MainViewModel`, добавлены characterization-тесты и один чистый extract для repair при загрузке истории. Поведение приложения для пользователя не менялось. Phase 1–3 завершены; **Phase 4 в процессе** (инкремент 1: settings) — см. [Phase 4](refactoring-phase-4-presentation.md).

## Артефакты в коде

| Файл | Назначение |
|------|------------|
| `llh/RefactorBaseline/RefactorBaselineInventory.swift` | Инвентарь: 12 `@Published` на Main + 7 на Settings (Phase 4), actions по buckets, триггеры `persistHistory`, карта OpenAI, UI-потребители |
| `llh/RefactorBaseline/HistoryEntryLoadRepair.swift` | Pure repair: `processing` → `failed` после прерванной сессии; очистка пустых formatted/study payloads |
| `llhTests/RefactorBaselineTests.swift` | Тесты-предохранители и inventory locks |

`MainViewModel.loadHistory` делегирует repair в `HistoryEntryLoadRepair.repairProfile` — логика та же, что была inline.

## Инвентарь MainViewModel

### Состояние UI

**Исходный снимок Phase 0:** 19 `@Published` на одном `MainViewModel`.

**После Phase 4 inc. 1:** 12 на `MainViewModel` + 7 на `SettingsViewModel` (`RefactorBaselineInventory`).

Main: capture/editor (`recognizedText`, `formattedRecognizedText`, `studyMaterials`, `capturedImage`, `isProcessing`), history (`profiles`, `selectedProfileID`, `selectedEntryID`), chrome (`statusMessage`, `showPermissionHelp`, `isFormattingRecognizedText`, `showsSessionReadingOverview`).

Settings VM: OpenAI models/token, OCR engine, default profile language, overlay timing, `isLoadingOpenAIModels`.

### Feature buckets (публичные действия)

- **Capture / permissions:** `triggerCapture`, `refreshPermissionState`, `openSystemSettings`
- **OCR / settings UI:** перенесены в `SettingsViewModel` (`selectOCREngine`, `switchToNextOCREngine`, token/model/overlay setters)
- **Formatting:** `retryFormattingForSelectedEntry` (на Main); длительность overlay — `SettingsViewModel.calculatedTranslationOverlayDuration`
- **History:** `deleteSelectedEntry`, `selectEntry`, `updateSelectedText`
- **Profiles:** `createProfile`, `selectProfile`, `deleteSelectedProfile` (`setDefaultNewProfileLearningLanguage` — на Settings VM, вызывается из `createProfile`)
- **Overlay:** `closeTranslationOverlay`, `toggleLastTranslationOverlay`
- **Study (words):** `retryStudyAssistantDataForSelectedEntry`
- **Session reading:** overview toggle, copy to pasteboard, `plainTextForSessionReadingCopy`

**Shortcuts** не экспонированы как public API: регистрация в `init` через `KeyboardShortcuts` (capture, switch OCR, close overlay, toggle last translation).

### Когда пишется история (`persistHistory`)

11 точек: удаление/создание профиля, правка текста, вставка после capture, старт/успех/ошибка форматирования, старт/успех/ошибка word study.

### OpenAI

Все шесть методов `OpenAIServing` существуют в `OpenAIService`.

**Исходный инвентарь Phase 0:** из `MainViewModel` напрямую вызывались models, AI OCR, format, words study.

**После Phase 3:** workflows за use cases; `ManageOpenAISettingsUseCase` вызывался из `MainViewModel`.

**После Phase 4 inc. 1:** UI настроек и 7 `@Published` — в `SettingsViewModel` → `ManageOpenAISettingsUseCase`. `MainViewModel` координирует capture/format/study и читает `settings.*` для конфигурации.

**Не подключены к UI:**

- `buildPhrasesStudyData`
- `buildGrammarStudyData`

Промпты: `wordsAnalysisPrompt(for:)` — централизован; format/recognize/phrases/grammar — inline в `OpenAIService` (кандидаты на extract в Phase 6).

### UI зависимости

`llhApp` владеет `StateObject` `MainViewModel`; `ContentView` и `MenuBarPanelView` наблюдают Main; настройки — `SettingsView(viewModel: main.settings)` в sheet (`Presentation/Settings/`).

## Покрытие тестами (Phase 0)

Новые тесты в `RefactorBaselineTests` закрывают пункты roadmap Phase 0:

- Multi-profile JSON roundtrip
- Legacy формат `history.json` как массив записей (не snapshot)
- Default profile всегда на индексе 0 после load
- Repair прерванного formatting / word study
- Persistence OCR engine (`OpenAISettingsStore.selectedOCREngineRawValue`)
- `OpenAIPromptBuilder.formattingRules` / `wordsAnalysisPrompt` / `OpenAIServiceError` descriptions

Ранее существующие тесты в `llhTests.swift` (overlay timing, legacy profile decode, single-profile persistence, prompt variants) остаются дополнительной сеткой.

## Критерии выхода Phase 0

| Критерий | Статус |
|----------|--------|
| Инвентарь в коде/тестах | выполнено |
| Regression coverage persistence/settings/prompts | выполнено |
| Без изменения продуктового поведения | выполнено |

## See Also

- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md) — Phase 4 в процессе (settings готов)
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — Phase 3 завершена
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — модели в `Domain/Models`
- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md) — завершённый Phase 1
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — полный пофазный план (архивный snapshot на 2026-05-26)
