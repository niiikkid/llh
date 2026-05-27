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

- Launch: `testLaunchShowsMainChrome` — заголовок «Помощник по изучению языков» (`AppDisplayStrings.productName`, v0.2 inc. 1).
- Settings: `testSettingsRouteOpensAndReturns` — «Настройки» → маршрут `AppMainRoute.settings` (inc. 2) → вкладка «Общие» → «Назад» (inc. 3; без кнопки «Закрыть»).
- Без live capture/OpenAI; performance test удалён из основного файла.

**v0.2 Inc. 4:** unit-тесты `TranslationResultPresentationResolverTests` — матрица loading / formatted / failed / rawOnly от `FormattingStatus` (без UI-теста вкладок; вкладки удалены).

**v0.2 Inc. 5:** `Phase3LoadGrammarStudyUseCaseTests`; grammar prompt test в `llhTests` (`openAIService_grammarStudyPrompt_targetsRussianLearner`).

**v0.2 Inc. 6:** `Phase3ManageProfilesUseCaseTests` (automation flags); `Phase5HistoryPersistenceTests` (`sqliteHistoryRepository_roundtripsSessionAutomationFlags`); `learningProfile_decodesLegacyPayloadWithoutAutomationFlags` в `llhTests`.

**v0.2 Inc. 7:** `translationOverlayDismissSchedule_onlyTimesTemporaryContent` в `llhTests` — `TranslationOverlayDismissSchedule.shouldScheduleAutomaticDismiss` (timer только при `dismissAfter != nil`). Overlay ✕ / Escape — manual UI verification.

**v0.2 Inc. 8:** `sessionReadingSequenceItem_*` в `llhTests` — succeeded word/grammar payloads vs processing/failed; eye/details UI — manual verification.

**v0.2 Inc. 9:** `learningLanguage_dockBadgeLabel_usesFlagOrClearsForAuto` в `llhTests`; session switch / restart badge — manual verification.

## Исправления существующих тестов

- `OCREngine.openai` → `.ai` в Phase 1/3 tests.
- `StructuredFormattedText(pinyinText: nil)` → `""`.
- Preflight enums: pattern matching вместо `==` (не `Equatable`).

## Карта `llhTests/` (по слоям)

| Слой / фаза | Файлы |
|-------------|--------|
| Baseline (0) | `RefactorBaselineTests`, `llhTests` (overlay timing + dismiss schedule, inc. 7; dock badge label, inc. 9) |
| Presentation (v0.2 inc. 4–5) | `TranslationResultPresentationResolverTests`; study tabs — manual / use-case tests |
| Repositories (1) | `Phase1RepositoryTests` |
| Domain (2) | `Phase2DomainModelsTests` |
| Use cases (3) | `Phase3*UseCaseTests`, `Phase3CaptureRegionUseCaseTests`, `Phase3LoadGrammarStudyUseCaseTests` (inc. 5); profiles automation (inc. 6) |
| Persistence (5) | `Phase5HistoryPersistenceTests` (inc. 6: SQLite automation columns) |
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

**Phase 10 завершена** — см. [Phase 10 Cleanup](refactoring-phase-10-cleanup.md).

## See Also

- [Refactoring Phase 10 Cleanup](refactoring-phase-10-cleanup.md) — финальный этап refactor
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — `RefactorBaselineInventory` / characterization
- [Refactoring Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md)
- [Refactoring Phase 5 SQLite Persistence](refactoring-phase-5-sqlite-persistence.md)
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md)
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md)
- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md)
- [v0.2 Product Plan](v0-2-product-plan.md) — UI smoke (inc. 1–3); resolver (inc. 4); grammar (inc. 5); automation (inc. 6); overlay dismiss (inc. 7); reading details (inc. 8); dock badge (inc. 9)
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — архивный snapshot §Phase 9–10
