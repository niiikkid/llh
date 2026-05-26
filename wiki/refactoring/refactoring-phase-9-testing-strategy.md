# Refactoring Phase 9 Testing Strategy

> Sources: llh project, 2026-05-27
> Raw: [Phase 9 testing strategy completion](../../raw/refactoring/2026-05-27-phase-9-testing-strategy-completion.md)
> Updated: 2026-05-27

## Overview

Phase 9 («Testing Strategy») **завершена**. Покрытие выровнено под архитектуру UI → ViewModels → UseCases → Repositories → Services: unit-тесты по фазам 1–8 сохранены; добавлены integration-style сценарии, migration failure/bootstrap fallback, расширенные prompt-тесты и UI smoke без live OpenAI/Screen Recording.

## Новые тестовые модули (`llhTests/`)

| Файл | Назначение |
|------|------------|
| `Phase9TestSupport.swift` | Общие fakes, temp `HistoryStorageLocations`, test image |
| `Phase9IntegrationTests.swift` | Capture/format/settings/bootstrap/repair/container smoke |
| `Phase9MigrationTests.swift` | Verification failure + corrupt DB → JSON fallback |
| `Phase9OpenAIPromptTests.swift` | OCR/format/phrases/grammar/pinyin prompt contracts |
| `Phase9CaptureViewModelTests.swift` | Permission denied + successful capture → history |

## Integration-style сценарии

- **Capture:** `CaptureRegionUseCase` end-to-end с fake permission/region/screenshot/OCR.
- **Format + history:** `FormatCapturedTextUseCase.perform` → `ManageHistoryUseCase` save/load.
- **Settings:** `preflightValidateAndSaveAPIKey` + `performValidateAndSaveAPIKey` с in-memory repos.
- **Startup repair:** interrupted `formattingStatus: .processing` → `.failed` через `loadSession`.
- **DI:** `AppDependencyContainer` + `makeMainViewModel()` на injected fakes.

## Migration и bootstrap

- `HistoryMigrationService` принимает `any HistoryRepository` для SQLite-импорта (тестируемый mismatch repository).
- **Failure:** verification mismatch → `HistoryPersistenceError.migrationVerificationFailed`, флаг миграции не выставляется.
- **Fallback:** повреждённый `history.sqlite` → `HistoryRepositoryBootstrap` возвращает JSON repository.

## UI tests (`llhUITests/`)

- Launch: заголовок «Language Learning Helper».
- Settings: кнопка «Настройки» → sheet с «Общие» → «Закрыть».
- Без live capture/OpenAI; performance test удалён из основного файла.

## Исправления существующих тестов

- `OCREngine.openai` → `.ai` в Phase 1/3 tests.
- `StructuredFormattedText(pinyinText: nil)` → `""`.
- Preflight enums: pattern matching вместо `==` (не `Equatable`).

## Карта `llhTests/` (по слоям)

| Слой / фаза | Файлы |
|-------------|--------|
| Baseline (0) | `RefactorBaselineTests`, `llhTests` |
| Repositories (1) | `Phase1RepositoryTests` |
| Domain (2) | `Phase2DomainModelsTests` |
| Use cases (3) | `Phase3*UseCaseTests`, `Phase3CaptureRegionUseCaseTests` |
| Persistence (5) | `Phase5HistoryPersistenceTests` |
| OpenAI (6) | `Phase6OpenAI*Tests`, `OpenAIHTTPClientTestSupport` |
| OCR/Capture (7) | `Phase7CaptureOCRTests` |
| Integration (9) | `Phase9IntegrationTests`, `Phase9MigrationTests`, `Phase9OpenAIPromptTests`, `Phase9CaptureViewModelTests`, `Phase9TestSupport` |

Правила: без live OpenAI, без user Keychain, без реального Screen Recording; persistence — temp dirs.

## Запуск

```bash
xcodebuild -scheme llh -destination 'platform=macOS' test -only-testing:llhTests/Phase9MigrationTests \
  -only-testing:llhTests/Phase9IntegrationTests -only-testing:llhTests/Phase9OpenAIPromptTests \
  -only-testing:llhTests/Phase9CaptureViewModelTests
```

Полный `llhTests` — в Xcode или `xcodebuild test -only-testing:llhTests` (дольше; возможны flaky при параллельном прогоне).

## Критерии выхода (roadmap)

| Критерий | Статус |
|----------|--------|
| Use cases с focused tests | ✅ Phase 3 + Phase 9 integration |
| Repositories с focused tests | ✅ Phase 1, 5 + Phase 9 migration |
| Migration failure + idempotency | ✅ Phase 5 + Phase 9 failure |
| OpenAI prompts/mapping без network | ✅ Phase 6 + Phase 9 prompts |
| OCR через mocks | ✅ Phase 3, 7 + Phase 9 capture |
| Settings/Keychain без user Keychain | ✅ in-memory fakes |
| Permission → UI state | ✅ Phase 9 CaptureViewModel |
| UI tests limited/stable | ✅ launch + settings |

## Следующий этап

**Phase 10** — cleanup и product decisions (dead study paths, shims, roadmap §Phase 10).

## See Also

- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — `RefactorBaselineInventory` / characterization
- [Refactoring Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md)
- [Refactoring Phase 5 SQLite Persistence](refactoring-phase-5-sqlite-persistence.md)
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md)
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md)
- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md)
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — архивный snapshot §Phase 9–10
