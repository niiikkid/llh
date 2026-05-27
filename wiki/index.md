# Knowledge Base Index

## refactoring

Планы и архитектурные решения по приведению llh к целевой слоистой архитектуре. **Фазы 0–10 завершены**; **v0.2 product plan complete** (Inc. 1–10); refactor aligned with Cursor rules.

| Article | Summary | Updated |
|---------|---------|---------|
| [v0.2 Product Plan](refactoring/v0-2-product-plan.md) | v0.2: **Inc. 1–10 done** — plan complete (Dock badge inc. 9). | 2026-05-27 |
| [Refactoring Phase 10 Cleanup](refactoring/refactoring-phase-10-cleanup.md) | Phase 10: removed unwired phrase API; grammar restored in v0.2 inc. 5; `overlayPrimaryText` dedup; `Services/` → Data/Infrastructure. | 2026-05-27 |
| [Refactoring Phase 9 Testing Strategy](refactoring/refactoring-phase-9-testing-strategy.md) | Phase 9: `Phase9*` tests; UI smoke; v0.2 inc. 4–9 (resolver, grammar, automation, overlay, reading details, dock badge). | 2026-05-27 |
| [Refactoring Phase 8 UI Decomposition](refactoring/refactoring-phase-8-ui-decomposition.md) | Phase 8: feature views + `StructuredFormattedText`; v0.2 inc. 1–10 (sessions, study, overlay, reading overview, dock badge). | 2026-05-27 |
| [Refactoring Phase 7 OCR Capture Permission](refactoring/refactoring-phase-7-ocr-capture-permission.md) | Phase 7: `OCRResult`, Vision/ScreenCaptureKit, cancellation; Phase 10 — capture services в `Infrastructure/Capture/`, hotkey cancel test. | 2026-05-27 |
| [Refactoring Phase 6 OpenAI Integration](refactoring/refactoring-phase-6-openai-integration.md) | Phase 6: HTTP/models/OCR/translation/study; facade в `Data/OpenAI/`; words + grammar study (v0.2 inc. 5). | 2026-05-27 |
| [Refactoring Phase 5 SQLite Persistence](refactoring/refactoring-phase-5-sqlite-persistence.md) | Phase 5: GRDB + JSON→SQLite; v0.2 inc. 6 — `v2_profile_session_automation`; JSON backup сохранён. | 2026-05-27 |
| [Refactoring Phase 4 Presentation](refactoring/refactoring-phase-4-presentation.md) | Phase 4: feature VMs; v0.2 inc. 2–9 — sessions, settings, study, overlay dismiss, reading sequence, dock badge. | 2026-05-27 |
| [Refactoring Phase 3 Use Cases](refactoring/refactoring-phase-3-use-cases.md) | Phase 3: 8 use cases; v0.2 inc. 5 grammar + inc. 6 `updateSessionAutomation`; phrase API removed in Phase 10. | 2026-05-27 |
| [Refactoring Phase 2 Domain Models](refactoring/refactoring-phase-2-domain-models.md) | Phase 2: `Domain/Models`; v0.2 inc. 6 automation flags; inc. 8 `SessionReadingSequenceItem` study fields; inc. 9 `dockBadgeLabel`; Phase 10 `overlayPrimaryText`. | 2026-05-27 |
| [Refactoring Phase 1 Boundaries And DI](refactoring/refactoring-phase-1-boundaries.md) | Phase 1: protocols, `AppDependencyContainer`; Phases 9–10 — tests + file layout cleanup. | 2026-05-27 |
| [Refactoring Phase 0 Baseline](refactoring/refactoring-phase-0-baseline.md) | Phase 0: инвентарь, `RefactorBaselineTests`; Phases 9–10 — safety net + `OpenAICallSite` = 5 (v0.2 inc. 5). | 2026-05-27 |
| [LLH Project Refactoring Roadmap](refactoring/project-refactoring-roadmap.md) | [Archived] Snapshot 2026-05-26; Phases 0–10 — в `refactoring-phase-*`. | 2026-05-27 |
