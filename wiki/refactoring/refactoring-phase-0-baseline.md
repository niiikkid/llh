# Refactoring Phase 0 Baseline

> Sources: llh project, 2026-05-26
> Raw: [Phase 0 baseline completion](../../raw/refactoring/2026-05-26-phase-0-baseline-completion.md)
> Updated: 2026-05-26

## Overview

Phase 0 («Baseline And Safety Net») завершена: зафиксирована поверхность `MainViewModel`, добавлены characterization-тесты и один чистый extract для repair при загрузке истории. Поведение приложения для пользователя не менялось. Phase 1 (протоколы и DI) выполнена отдельно — см. [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md).

## Артефакты в коде

| Файл | Назначение |
|------|------------|
| `llh/RefactorBaseline/RefactorBaselineInventory.swift` | Инвентарь: 19 `@Published`, публичные действия по feature buckets, триггеры `persistHistory`, карта OpenAI, UI-потребители |
| `llh/RefactorBaseline/HistoryEntryLoadRepair.swift` | Pure repair: `processing` → `failed` после прерванной сессии; очистка пустых formatted/study payloads |
| `llhTests/RefactorBaselineTests.swift` | Тесты-предохранители и inventory locks |

`MainViewModel.loadHistory` делегирует repair в `HistoryEntryLoadRepair.repairProfile` — логика та же, что была inline.

## Инвентарь MainViewModel

### Состояние UI (19 `@Published`)

Capture/editor: `recognizedText`, `formattedRecognizedText`, `studyMaterials`, `capturedImage`, `isProcessing`. History/profiles: `profiles`, `selectedProfileID`, `selectedEntryID`. Settings: `selectedOpenAIModelID`, `availableOpenAIModels`, `selectedOCREngine`, `defaultNewProfileLearningLanguage`, overlay timing. Chrome: `statusMessage`, `showPermissionHelp`, loading flags, `showsSessionReadingOverview`.

### Feature buckets (публичные действия)

- **Capture / permissions:** `triggerCapture`, `refreshPermissionState`, `openSystemSettings`
- **OCR:** `selectOCREngine`, `switchToNextOCREngine`
- **Formatting:** `retryFormattingForSelectedEntry`, `calculatedTranslationOverlayDuration`
- **History:** `deleteSelectedEntry`, `selectEntry`, `updateSelectedText`
- **Profiles:** `createProfile`, `selectProfile`, `deleteSelectedProfile`, `setDefaultNewProfileLearningLanguage`
- **OpenAI / overlay settings:** token/model/OCR/overlay setters
- **Overlay:** `closeTranslationOverlay`, `toggleLastTranslationOverlay`
- **Study (words):** `retryStudyAssistantDataForSelectedEntry`
- **Session reading:** overview toggle, copy to pasteboard, `plainTextForSessionReadingCopy`

**Shortcuts** не экспонированы как public API: регистрация в `init` через `KeyboardShortcuts` (capture, switch OCR, close overlay, toggle last translation).

### Когда пишется история (`persistHistory`)

11 точек: удаление/создание профиля, правка текста, вставка после capture, старт/успех/ошибка форматирования, старт/успех/ошибка word study.

### OpenAI

Все шесть методов `OpenAIServing` существуют в `OpenAIService`. Из `MainViewModel` вызываются четыре: models, AI OCR, format, words study.

**Не подключены к UI / ViewModel:**

- `buildPhrasesStudyData`
- `buildGrammarStudyData`

Промпты: `wordsAnalysisPrompt(for:)` — централизован; format/recognize/phrases/grammar — inline в `OpenAIService` (кандидаты на extract в Phase 6).

### UI зависимости

`llhApp` владеет `StateObject` ViewModel; `ContentView` и `MenuBarPanelView` — основные наблюдатели; settings tabs (`OpenAISettingsTab`, `OverlayTimingSettingsTab`) внутри `ContentView`.

## Покрытие тестами (Phase 0)

Новые тесты в `RefactorBaselineTests` закрывают пункты roadmap Phase 0:

- Multi-profile JSON roundtrip
- Legacy формат `history.json` как массив записей (не snapshot)
- Default profile всегда на индексе 0 после load
- Repair прерванного formatting / word study
- Persistence OCR engine (`OpenAISettingsStore.selectedOCREngineRawValue`)
- `formattingRules` / words prompt / `OpenAIServiceError` descriptions

Ранее существующие тесты в `llhTests.swift` (overlay timing, legacy profile decode, single-profile persistence, prompt variants) остаются дополнительной сеткой.

## Критерии выхода Phase 0

| Критерий | Статус |
|----------|--------|
| Инвентарь в коде/тестах | выполнено |
| Regression coverage persistence/settings/prompts | выполнено |
| Без изменения продуктового поведения | выполнено |

## See Also

- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md) — завершённый Phase 1
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — полный пофазный план (архивный snapshot на 2026-05-26)
