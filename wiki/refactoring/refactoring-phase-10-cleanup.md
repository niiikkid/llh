# Refactoring Phase 10 Cleanup

> Sources: llh project, 2026-05-27
> Raw: [Phase 10 cleanup completion](../../raw/refactoring/2026-05-27-phase-10-cleanup-completion.md)
> Updated: 2026-05-27

## Overview

Phase 10 («Cleanup And Product Decisions») **завершена**. Удалены неподключённые OpenAI study API (phrases/grammar), зафиксированы продуктовые решения по отложенным фичам из `TODO.txt`, устранён дубликат overlay display logic, перенесены остатки `llh/Services/` в целевые слои, JSON backup сохранён.

## Продуктовые решения

| Тема | Решение |
|------|---------|
| Phrase / grammar study API | **Удалены** из кода; вернуть через use case + UI, когда появятся в roadmap |
| Word-click translation, session vocabulary, cost stats, speech | **Отложены** — см. `TODO.txt` |
| Повторный hotkey захвата | **Реализовано**: отмена активного захвата при `isProcessing`; форматирование после capture hotkey не отменяется |
| JSON `history.json` | **Сохранён** как backup / fallback (`HistoryRepositoryBootstrap`) |

Модели `StudyMaterials.phrases` / `grammar` и legacy decode в `CapturedTextEntry` **оставлены** для старых записей истории; `HistoryEntryLoadRepair` по-прежнему чинит прерванные `phrasesStatus` / `grammarStatus`.

## Удалённый мёртвый код

- `OpenAIServing.buildPhrasesStudyData` / `buildGrammarStudyData`
- `OpenAIStudyService` phrase/grammar HTTP + DTOs
- `OpenAIPromptBuilder.phrasesStudy*` / `grammarStudy*` / `pinyinTonePromptParagraph`
- `RefactorBaselineInventory.unwiredOpenAIStudyAPIs`

Живой study path: **`buildWordsStudyData`** → `LoadWordStudyUseCase` → `StudyViewModel`.

## Display helpers

`StructuredFormattedText.overlayPrimaryText` — единый источник для overlay panel и `TranslationOverlayTiming.visibleTexts` (пиньинь → cleaned → russian, с trim).

## Перенос `llh/Services/`

| Было | Стало |
|------|--------|
| `Services/OpenAIService.swift` | `Data/OpenAI/OpenAIService.swift` |
| `Services/HistoryPersistenceService.swift` | `Data/Persistence/HistoryPersistenceService.swift` |
| `Services/RegionSelectionService.swift` | `Infrastructure/Capture/RegionSelectionService.swift` |
| `Services/ScreenRecordingPermissionService.swift` | `Infrastructure/Capture/ScreenRecordingPermissionService.swift` |

Папка `llh/Services/` удалена. Protocol conformances в `Domain/Services/CaptureServiceProtocols.swift` без изменений.

## Тесты (`llhTests/`)

| Файл | Назначение |
|------|------------|
| `Phase10CaptureViewModelTests.swift` | Hotkey при `isProcessing` → cancel + status «отменён» |
| `Phase9OpenAIPromptTests.swift` | `overlayPrimaryText` precedence (вместо phrase/grammar prompts) |
| `RefactorBaselineTests.swift` | `OpenAICallSite` count **4** |

```bash
xcodebuild -scheme llh -destination 'platform=macOS' test \
  -only-testing:llhTests/Phase10CaptureViewModelTests \
  -only-testing:llhTests/RefactorBaselineTests
```

## Критерии выхода (roadmap)

| Критерий | Статус |
|----------|--------|
| Нет unused OpenAI study paths без intent | ✅ только words |
| Obsolete persistence не удалён без approval | ✅ JSON backup |
| Крупные legacy файлы уменьшены | ✅ `Services/` убран, overlay dedup |

## Definition of Done (refactor)

Roadmap §Definition Of Done — выполнен вместе с Phases 0–9. Новые фичи — через feature VMs + use cases, не через расширение monolith.

## See Also

- [Refactoring Phase 9 Testing Strategy](refactoring-phase-9-testing-strategy.md)
- [Refactoring Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md) — display helpers в UI
- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md) — hotkey cancel при capture
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — `overlayPrimaryText`, legacy study decode
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — исходный инвентарь unwired APIs (superseded)
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md)
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md)
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — архивный план §Phase 10
