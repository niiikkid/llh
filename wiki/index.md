# Knowledge Base Index

## refactoring

Планы и архитектурные решения по приведению llh к целевой слоистой архитектуре. **Фазы 0–10 завершены**; refactor aligned with Cursor rules.

| Article | Summary | Updated |
|---------|---------|---------|
| [v0.2 Product Plan](refactoring/v0-2-product-plan.md) | v0.2 plan: **Increments 1 and 10 done**; increments 2–9 pending (sessions page, settings, translation state, study tabs, automation, overlay, Dock badge). | 2026-05-27 |
| [Refactoring Phase 10 Cleanup](refactoring/refactoring-phase-10-cleanup.md) | Phase 10: removed unwired phrase/grammar OpenAI API; product decisions; `overlayPrimaryText` dedup; relocated `Services/` → Data/Infrastructure; hotkey cancel test. | 2026-05-27 |
| [Refactoring Phase 9 Testing Strategy](refactoring/refactoring-phase-9-testing-strategy.md) | Phase 9: `Phase9*` integration/migration/prompt/VM tests; UI launch+settings; migration verify failure; bootstrap JSON fallback; fixes Phase 1/3 stale OCR tests. | 2026-05-27 |
| [Refactoring Phase 8 UI Decomposition](refactoring/refactoring-phase-8-ui-decomposition.md) | Phase 8 завершена: feature views + `StructuredFormattedText`; v0.2 inc. 1 (UI polish) и inc. 10 (`MainWindowActivator`, single main window). | 2026-05-27 |
| [Refactoring Phase 7 OCR Capture Permission](refactoring/refactoring-phase-7-ocr-capture-permission.md) | Phase 7: `OCRResult`, Vision/ScreenCaptureKit, cancellation; Phase 10 — capture services в `Infrastructure/Capture/`, hotkey cancel test. | 2026-05-27 |
| [Refactoring Phase 6 OpenAI Integration](refactoring/refactoring-phase-6-openai-integration.md) | Phase 6: HTTP/models/OCR/translation/study; Phase 10 — facade в `Data/OpenAI/`, только words study API. | 2026-05-27 |
| [Refactoring Phase 5 SQLite Persistence](refactoring/refactoring-phase-5-sqlite-persistence.md) | Phase 5: GRDB + JSON→SQLite; Phase 10 — JSON backup сохранён, `HistoryPersistenceService` в `Data/Persistence/`. | 2026-05-27 |
| [Refactoring Phase 4 Presentation](refactoring/refactoring-phase-4-presentation.md) | Phase 4: 6 feature VMs; Phases 8–10 — split UI, tests, cleanup. | 2026-05-27 |
| [Refactoring Phase 3 Use Cases](refactoring/refactoring-phase-3-use-cases.md) | Phase 3: 7 use cases; Phase 10 — phrase/grammar API removed. | 2026-05-27 |
| [Refactoring Phase 2 Domain Models](refactoring/refactoring-phase-2-domain-models.md) | Phase 2: `Domain/Models`, display helpers; Phase 10 — `overlayPrimaryText`. | 2026-05-27 |
| [Refactoring Phase 1 Boundaries And DI](refactoring/refactoring-phase-1-boundaries.md) | Phase 1: protocols, `AppDependencyContainer`; Phases 9–10 — tests + file layout cleanup. | 2026-05-27 |
| [Refactoring Phase 0 Baseline](refactoring/refactoring-phase-0-baseline.md) | Phase 0: инвентарь, `RefactorBaselineTests`; Phases 9–10 — safety net + `OpenAICallSite` = 4. | 2026-05-27 |
| [LLH Project Refactoring Roadmap](refactoring/project-refactoring-roadmap.md) | [Archived] Snapshot 2026-05-26; Phases 0–10 — в `refactoring-phase-*`. | 2026-05-27 |
