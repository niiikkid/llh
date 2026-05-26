# Knowledge Base Index

## refactoring

Планы и архитектурные решения по приведению llh к целевой слоистой архитектуре. **Фазы 0–9 завершены**; следующий этап — Phase 10 (cleanup и product decisions).

| Article | Summary | Updated |
|---------|---------|---------|
| [Refactoring Phase 9 Testing Strategy](refactoring/refactoring-phase-9-testing-strategy.md) | Phase 9: `Phase9*` integration/migration/prompt/VM tests; UI launch+settings; migration verify failure; bootstrap JSON fallback; fixes Phase 1/3 stale OCR tests. | 2026-05-27 |
| [Refactoring Phase 8 UI Decomposition](refactoring/refactoring-phase-8-ui-decomposition.md) | Phase 8 завершена: `Presentation/Main/ContentView` + feature views; `StructuredFormattedText` display helpers; per-VM `statusMessage`; Main без `@Published`. | 2026-05-27 |
| [Refactoring Phase 7 OCR Capture Permission](refactoring/refactoring-phase-7-ocr-capture-permission.md) | Phase 7: `OCRResult`, Vision/ScreenCaptureKit, cancellation; Phase 9 — capture integration + `CaptureViewModel` permission tests. | 2026-05-27 |
| [Refactoring Phase 6 OpenAI Integration](refactoring/refactoring-phase-6-openai-integration.md) | Phase 6: HTTP/models/OCR/translation/study; Phase 9 — prompt contracts + Phase 6 mapping tests. | 2026-05-27 |
| [Refactoring Phase 5 SQLite Persistence](refactoring/refactoring-phase-5-sqlite-persistence.md) | Phase 5: GRDB + JSON→SQLite; Phase 9 — migration verify failure + bootstrap JSON fallback. | 2026-05-27 |
| [Refactoring Phase 4 Presentation](refactoring/refactoring-phase-4-presentation.md) | Phase 4: 6 feature VMs; Phase 8 — split views; Phase 9 — UI smoke + Capture VM tests. | 2026-05-27 |
| [Refactoring Phase 3 Use Cases](refactoring/refactoring-phase-3-use-cases.md) | Phase 3: 7 use cases; Phase 9 — capture/format/settings integration tests. | 2026-05-27 |
| [Refactoring Phase 2 Domain Models](refactoring/refactoring-phase-2-domain-models.md) | Phase 2: `Domain/Models`, display helpers; Phase 9 — prompt/display test coverage. | 2026-05-27 |
| [Refactoring Phase 1 Boundaries And DI](refactoring/refactoring-phase-1-boundaries.md) | Phase 1: protocols, `AppDependencyContainer`; Phase 9 — injected container smoke. | 2026-05-27 |
| [Refactoring Phase 0 Baseline](refactoring/refactoring-phase-0-baseline.md) | Phase 0: инвентарь, `RefactorBaselineTests`; Phase 9 расширяет safety net (integration/migration/UI). | 2026-05-27 |
| [LLH Project Refactoring Roadmap](refactoring/project-refactoring-roadmap.md) | [Archived] Snapshot 2026-05-26; Phases 0–9 — в `refactoring-phase-*`; далее Phase 10 cleanup. | 2026-05-27 |
