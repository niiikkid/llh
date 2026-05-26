# Knowledge Base Index

## refactoring

Планы и архитектурные решения по приведению llh к целевой слоистой архитектуре.

| Article | Summary | Updated |
|---------|---------|---------|
| [Refactoring Phase 7 OCR Capture Permission](refactoring/refactoring-phase-7-ocr-capture-permission.md) | Phase 7 завершена: `OCRResult`, `VisionOCRService`, `ScreenCaptureKitCaptureService`, cancellation, permission UX. | 2026-05-26 |
| [Refactoring Phase 6 OpenAI Integration](refactoring/refactoring-phase-6-openai-integration.md) | Phase 6 завершена: HTTP/models/OCR/translation/study; settings/keychain + timeout; `OpenAIOCRService` → `OCRResult`. | 2026-05-26 |
| [Refactoring Phase 5 SQLite Persistence](refactoring/refactoring-phase-5-sqlite-persistence.md) | Phase 5: GRDB + `history.sqlite`, JSON→SQLite; Phase 6–7 завершены. | 2026-05-26 |
| [Refactoring Phase 4 Presentation](refactoring/refactoring-phase-4-presentation.md) | Phase 4: 6 feature VMs; `CaptureViewModel` + Phase 7 permission/cancel; Main ~157 строк. | 2026-05-26 |
| [Refactoring Phase 3 Use Cases](refactoring/refactoring-phase-3-use-cases.md) | Phase 3: 7 use cases; capture/OCR → `OCRResult`; Phase 6–7 завершены. | 2026-05-26 |
| [Refactoring Phase 2 Domain Models](refactoring/refactoring-phase-2-domain-models.md) | Phase 2: `Domain/Models`, `Data/OpenAI`, `OCRResult`; Infrastructure OCR/capture (Phase 7). | 2026-05-26 |
| [Refactoring Phase 1 Boundaries And DI](refactoring/refactoring-phase-1-boundaries.md) | Phase 1: protocols, `AppDependencyContainer`; `VisionOCRService`, `ScreenCaptureKitCaptureService` (Phase 7). | 2026-05-26 |
| [Refactoring Phase 0 Baseline](refactoring/refactoring-phase-0-baseline.md) | Phase 0: инвентарь `@Published`, characterization-тесты, `HistoryEntryLoadRepair`. | 2026-05-26 |
| [LLH Project Refactoring Roadmap](refactoring/project-refactoring-roadmap.md) | [Archived] Подробный пофазный план приведения текущего macOS Swift проекта к новым Cursor rules: слои, DI, use cases, repositories, persistence migration, OpenAI/OCR boundaries и тестирование. | 2026-05-26 |
