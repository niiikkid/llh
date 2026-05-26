# Refactoring Phase 2 Domain Models

> Sources: llh project, 2026-05-26
> Raw: [Phase 2 domain models completion](../../raw/refactoring/2026-05-26-phase-2-domain-models-completion.md); [Phase 2 Data/OpenAI completion](../../raw/refactoring/2026-05-26-phase-2-data-openai-completion.md)
> Updated: 2026-05-26

## Overview

Phase 2 («Extract Domain Models And Errors») **завершена по основным критериям roadmap** в два инкремента без изменения продуктового поведения:

1. **Инкремент 1** — product-модели из `MainViewModel.swift` → `llh/Domain/Models/` (`MainViewModel` ~1316 → ~744 строк).
2. **Инкремент 2** — JSON snapshot и OpenAI-границы в Data: `HistoryStoreSnapshot`, `OpenAIModel`, `OpenAIServiceError`, `OpenAIPromptBuilder`; протокол `OpenAIServing` → `Domain/Services/`. Промпты убраны из `LearningLanguage`.

Опционально остаётся ввести `Domain/Errors` для **workflow**-ошибок (отдельно от `OpenAIServiceError` в Data). Следующая фаза — **Phase 3** (use cases).

## Инкремент 1 — Domain/Models

| Файл | Содержимое |
|------|------------|
| `FormattingStatus.swift` | Статусы форматирования и study |
| `LearningLanguage.swift` | Язык сессии (UI: `title`, `supportsWordStudy`) |
| `OCREngine.swift` | local / AI |
| `StructuredFormattedText.swift` | Очищенный текст, пиньинь, перевод |
| `StudyMaterials.swift` | Study payloads, legacy `StudyAssistantData` decode |
| `CapturedTextEntry.swift` | Запись истории, legacy `Codable`, `NSImage?` только in-memory |
| `LearningProfile.swift` | Профиль, `LearningProfileKind`, default profile |
| `SessionReadingSequenceItem.swift` | Режим «вся сессия» |
| `TranslationOverlayTiming.swift` | `LatestTranslationLookup`, расчёт длительности overlay |

## Инкремент 2 — Data и OpenAI

### Data/Persistence

| Файл | Содержимое |
|------|------------|
| `HistoryStoreSnapshot.swift` | On-disk JSON для `history.json` (не domain entity) |

`HistoryPersistenceService` сохраняет load/save и legacy-миграцию из массива записей.

### Data/OpenAI

| Файл | Содержимое |
|------|------------|
| `OpenAIModel.swift` | Модель для списка в настройках |
| `OpenAIServiceError.swift` | Ошибки API с русскими `LocalizedError` |
| `OpenAIPromptBuilder.swift` | Все промпты: format, AI OCR, words/phrases/grammar, pinyin rules, instruction names |

### Domain/Services

| Файл | Содержимое |
|------|------------|
| `OpenAIServing.swift` | Протокол OpenAI-операций (ранее в `OpenAIService.swift`) |

`OpenAIService` (~737 строк) — HTTP, DTO, mapping; промпты только через `OpenAIPromptBuilder`.

## MainViewModel

- ~744 строк: координация UI/workflows, `CaptureTriggerSource`
- DI из Phase 1: `AppDependencyContainer` → `init(dependencies:)`
- Workflows пока в ViewModel (Phase 3)

## Покрытие тестами

`llhTests/Phase2DomainModelsTests.swift`:

- `LearningProfile.defaultProfile()` — `.auto`, `.default`, `isDefaultProfile`
- `StructuredFormattedText.sessionListSourceDisplay` — пиньинь для `.chinese`
- `TranslationOverlayTiming.duration` — clamp минимума (1 с)
- `openAIPromptBuilder_formatRecognizedTextUserPrompt_includesRawText`
- `historyStoreSnapshot_roundtripsThroughJSON`

`RefactorBaselineTests` / `llhTests.swift` — prompt и error coverage через `OpenAIPromptBuilder` и `OpenAIServiceError`.

## Критерии выхода Phase 2

| Критерий | Статус |
|----------|--------|
| Модели не в `MainViewModel.swift` | выполнено |
| Legacy history decode на `CapturedTextEntry` | выполнено |
| Без изменения продуктового поведения | выполнено |
| Prompt-строки вне `LearningLanguage` | выполнено |
| Persistence snapshots в Data | выполнено |
| `OpenAIModel` / `OpenAIServiceError` в Data/OpenAI | выполнено |
| `OpenAIServing` в Domain | выполнено |
| `Domain/Errors` (workflow) | опционально, не блокирует Phase 3 |

## Следующий шаг

**Phase 3** — use cases по одному workflow: `CaptureRegionUseCase` → recognize → format → history → profiles → word study → OpenAI settings.

## See Also

- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md) — DI и repositories
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь и safety net
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — полный план (архивный snapshot)
