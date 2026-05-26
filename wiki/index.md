# Knowledge Base Index

## refactoring

Планы и архитектурные решения по приведению llh к целевой слоистой архитектуре. **Фазы 0–8 завершены**; следующий этап — Phase 9 (testing strategy).

| Article | Summary | Updated |
|---------|---------|---------|
| [Refactoring Phase 8 UI Decomposition](refactoring/refactoring-phase-8-ui-decomposition.md) | Phase 8 завершена: `Presentation/Main/ContentView` + feature views; `StructuredFormattedText` display helpers; per-VM `statusMessage`; Main без `@Published`. | 2026-05-27 |
| [Refactoring Phase 7 OCR Capture Permission](refactoring/refactoring-phase-7-ocr-capture-permission.md) | Phase 7: `OCRResult`, Vision/ScreenCaptureKit Infrastructure, cancellation, permission UX; UI banner — `CapturePermissionBannerView` (Phase 8). | 2026-05-27 |
| [Refactoring Phase 6 OpenAI Integration](refactoring/refactoring-phase-6-openai-integration.md) | Phase 6: HTTP/models/OCR/translation/study; settings/keychain + timeout; `OpenAIOCRService` → `OCRResult`. | 2026-05-27 |
| [Refactoring Phase 5 SQLite Persistence](refactoring/refactoring-phase-5-sqlite-persistence.md) | Phase 5: GRDB + `history.sqlite`, JSON→SQLite; Phases 6–8 завершены. | 2026-05-27 |
| [Refactoring Phase 4 Presentation](refactoring/refactoring-phase-4-presentation.md) | Phase 4: 6 feature VMs; Phase 8 закрыла split `ContentView` (feature views в `Presentation/`). | 2026-05-27 |
| [Refactoring Phase 3 Use Cases](refactoring/refactoring-phase-3-use-cases.md) | Phase 3: 7 use cases; capture/OCR → `OCRResult`; Phases 6–8 завершены. | 2026-05-27 |
| [Refactoring Phase 2 Domain Models](refactoring/refactoring-phase-2-domain-models.md) | Phase 2: `Domain/Models`; Phase 8 — display helpers на `StructuredFormattedText`. | 2026-05-27 |
| [Refactoring Phase 1 Boundaries And DI](refactoring/refactoring-phase-1-boundaries.md) | Phase 1: protocols, `AppDependencyContainer`; Main без `@Published` после Phase 8. | 2026-05-27 |
| [Refactoring Phase 0 Baseline](refactoring/refactoring-phase-0-baseline.md) | Phase 0: инвентарь, characterization-тесты; snapshot `@Published` после Phase 8 (0+24 на feature VMs). | 2026-05-27 |
| [LLH Project Refactoring Roadmap](refactoring/project-refactoring-roadmap.md) | [Archived] Пофазный план (snapshot 2026-05-26): слои, DI, use cases, persistence, OpenAI/OCR, UI decomposition §Phase 8. | 2026-05-26 |
