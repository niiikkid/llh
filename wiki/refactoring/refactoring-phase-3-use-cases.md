# Refactoring Phase 3 Use Cases

> Sources: llh project, 2026-05-26
> Raw: [Phase 3 capture use cases completion](../../raw/refactoring/2026-05-26-phase-3-capture-use-cases-completion.md)
> Updated: 2026-05-26

## Overview

Phase 3 («Extract Use Cases Workflow By Workflow») **в процессе**. Первый инкремент завершён без изменения продуктового поведения: capture + OCR вынесены в `RecognizeTextUseCase` и `CaptureRegionUseCase`. `MainViewModel` по-прежнему координирует UI, историю, overlay и форматирование.

## Завершённый инкремент — capture и recognize

| Файл | Назначение |
|------|------------|
| `Domain/Errors/RegionSelectionError.swift` | Ошибки выделения области (`cancelled`, `noScreen`) |
| `Domain/UseCases/RecognizeTextUseCase.swift` | Local OCR vs AI OCR по `OCREngine` |
| `Domain/UseCases/CaptureRegionUseCase.swift` | Permission → region → screenshot → recognize |

### CaptureRegionOutcome

| Исход | Смысл |
|-------|--------|
| `permissionDenied` | Нет Screen Recording |
| `selectionCancelled` | Пользователь отменил выделение |
| `noTextFound(image:)` | OCR вернул пустую строку |
| `captured(image:text:)` | Успех |

Use case не пишет в историю и не трогает overlay — это остаётся в `MainViewModel.startCaptureFlow`.

### DI

`AppDependencyContainer` содержит `recognizeTextUseCase` и `captureRegionUseCase`; сборка через `makeCaptureUseCases(...)`.

`RegionSelectionService` бросает `RegionSelectionError` (раньше — вложенный `SelectionError`).

## MainViewModel после инкремента

- ~721 строк
- Capture: `captureRegionUseCase.execute` + mapping outcomes → `@Published`, history, `formatEntryText`
- Ещё в ViewModel: `formatEntryText`, study load, profiles/history CRUD, settings, overlay, shortcuts

## Покрытие тестами

`llhTests/Phase3CaptureRegionUseCaseTests.swift` (7 тестов, fakes):

- permission denied / selection cancelled / no text / captured
- local vs AI recognize; AI без API key → `OpenAIServiceError.invalidTokenFormat`

## Критерии выхода Phase 3 (roadmap)

| Use case | Статус |
|----------|--------|
| `CaptureRegionUseCase` | выполнено |
| `RecognizeTextUseCase` | выполнено (в составе capture) |
| `FormatCapturedTextUseCase` | следующий шаг |
| `ManageHistoryUseCase` | не начато |
| `ManageProfilesUseCase` | не начато |
| `LoadWordStudyUseCase` | не начато |
| `ManageOpenAISettingsUseCase` | не начато |

Полный Phase 3 завершён, когда `MainViewModel` делегирует все перечисленные workflows, а use cases покрыты fake-driven тестами.

## Следующий шаг

**`FormatCapturedTextUseCase`** — вынести `formatEntryText` и связанное состояние форматирования из `MainViewModel`.

## See Also

- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — модели и Data/OpenAI границы до use cases
- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md) — протоколы и контейнер
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь MainViewModel
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — полный план (архивный snapshot)
