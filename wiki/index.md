# Knowledge Base Index

## refactoring

Планы и архитектурные решения по приведению llh к целевой слоистой архитектуре.

| Article | Summary | Updated |
|---------|---------|---------|
| [Refactoring Phase 4 Presentation](refactoring/refactoring-phase-4-presentation.md) | Phase 4 завершена: 6 feature VMs + overlay; 1+4+1+2+4+7 `@Published`, Main ~157 строк; далее Phase 5 SQLite. | 2026-05-26 |
| [Refactoring Phase 3 Use Cases](refactoring/refactoring-phase-3-use-cases.md) | Phase 3 завершена: 7 use cases, 56 unit-тестов; на конец Phase 3 Main ~783 строк без прямых OpenAI/repo вызовов. | 2026-05-26 |
| [Refactoring Phase 2 Domain Models](refactoring/refactoring-phase-2-domain-models.md) | Phase 2 завершена: `Domain/Models`, `Data/Persistence`, `Data/OpenAI` (`OpenAIPromptBuilder`), `OpenAIServing` в Domain; опционально `Domain/Errors`. | 2026-05-26 |
| [Refactoring Phase 1 Boundaries And DI](refactoring/refactoring-phase-1-boundaries.md) | Phase 1 завершена: repositories, capture/OCR protocols, `AppDependencyContainer`; Phase 4 — шесть feature VMs + overlay из того же графа. | 2026-05-26 |
| [Refactoring Phase 0 Baseline](refactoring/refactoring-phase-0-baseline.md) | Phase 0: исходный снимок 19 `@Published` на Main; сейчас 1+4+1+2+4+7 по feature VMs; characterization-тесты, `HistoryEntryLoadRepair`. | 2026-05-26 |
| [LLH Project Refactoring Roadmap](refactoring/project-refactoring-roadmap.md) | [Archived] Подробный пофазный план приведения текущего macOS Swift проекта к новым Cursor rules: слои, DI, use cases, repositories, persistence migration, OpenAI/OCR boundaries и тестирование. | 2026-05-26 |
