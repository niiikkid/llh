# Knowledge Base Index

## refactoring

Планы и архитектурные решения по приведению llh к целевой слоистой архитектуре.

| Article | Summary | Updated |
|---------|---------|---------|
| [Refactoring Phase 6 OpenAI Integration](refactoring/refactoring-phase-6-openai-integration.md) | Phase 6 PR 3: `OpenAIModelsService` (`GET /v1/models`); PR 2 `OpenAIHTTPClient`; далее PR 4 AI OCR boundary. | 2026-05-26 |
| [Refactoring Phase 5 SQLite Persistence](refactoring/refactoring-phase-5-sqlite-persistence.md) | Phase 5 (основное): GRDB + `history.sqlite`, JSON→SQLite миграция; Phase 6 PR 2–3 (HTTP + models) в работе. | 2026-05-26 |
| [Refactoring Phase 4 Presentation](refactoring/refactoring-phase-4-presentation.md) | Phase 4 завершена: 6 feature VMs + overlay; 1+4+1+2+4+7 `@Published`, Main ~157 строк; Phase 5 SQLite подключена. | 2026-05-26 |
| [Refactoring Phase 3 Use Cases](refactoring/refactoring-phase-3-use-cases.md) | Phase 3 завершена: 7 use cases; `ManageHistoryUseCase` → `HistoryRepository` (SQLite после Phase 5). | 2026-05-26 |
| [Refactoring Phase 2 Domain Models](refactoring/refactoring-phase-2-domain-models.md) | Phase 2: `Domain/Models`, `Data/Persistence`, `Data/OpenAI` (+ Phase 6 HTTP/models services), `OpenAIServing`. | 2026-05-26 |
| [Refactoring Phase 1 Boundaries And DI](refactoring/refactoring-phase-1-boundaries.md) | Phase 1: protocols, `AppDependencyContainer`, `HistoryRepositoryBootstrap` (Phase 5). | 2026-05-26 |
| [Refactoring Phase 0 Baseline](refactoring/refactoring-phase-0-baseline.md) | Phase 0: инвентарь `@Published`, characterization-тесты, `HistoryEntryLoadRepair` (актуален для SQLite load). | 2026-05-26 |
| [LLH Project Refactoring Roadmap](refactoring/project-refactoring-roadmap.md) | [Archived] Подробный пофазный план приведения текущего macOS Swift проекта к новым Cursor rules: слои, DI, use cases, repositories, persistence migration, OpenAI/OCR boundaries и тестирование. | 2026-05-26 |
