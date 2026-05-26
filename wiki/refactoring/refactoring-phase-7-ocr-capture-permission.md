# Refactoring Phase 7 OCR Capture Permission

> Sources: llh project, 2026-05-26; Apple Vision documentation (Context7), 2026-05-26
> Raw: [Phase 7 capture OCR permission completion](../../raw/refactoring/2026-05-26-phase-7-capture-ocr-permission-completion.md)
> Updated: 2026-05-27

## Overview

Phase 7 («OCR, Capture And Permission Polish») **завершена**. Capture/OCR flows стали структурированными, отменяемыми и тестируемыми через fakes; тяжёлая работа не блокирует main thread.

## Domain

| Тип | Назначение |
|-----|------------|
| `OCRResult` | `text` + `lines`, `isEmpty` |
| `ScreenRecordingPermissionStatus` | `.authorized` / `.denied` |

Протоколы (`CaptureServiceProtocols.swift`):

- `OCRServing` → `OCRResult`
- `OpenAIOCRServing` → `OCRResult`
- `ScreenRecordingPermissionChecking` → `permissionStatus` + `requestPermission()` (без автозапроса в use case)
- `RegionSelecting` → `cancelActiveSelection()` (`@MainActor`)

## Infrastructure

```text
Infrastructure/OCR/
  VisionOCRService.swift      — VNRecognizeTextRequest в Task.detached
  OCRImagePreprocessor.swift  — JPEG encode для AI OCR (off main actor)

Infrastructure/Capture/
  ScreenCaptureKitCaptureService.swift — SCScreenshotManager / SCShareableContent
```

Удалены legacy `Services/OCRService.swift`, `Services/ScreenshotService.swift`.

## Use cases

| Use case | Изменения |
|----------|-----------|
| `RecognizeTextUseCase` | `Sendable`, не `@MainActor`; `Task.checkCancellation()`; возвращает `OCRResult` |
| `CaptureRegionUseCase` | `cancelActiveCapture()`; cancellation checkpoints; `.text` в outcome |

## Presentation

`CaptureViewModel`:

- `@Published permissionStatus`
- `requestScreenRecordingAccess()` — явный запрос (не в цикле capture)
- Повторный hotkey во время `isProcessing` → `cancelActiveCapture()`
- `CancellationError` → «Захват отменён»

`CapturePermissionBannerView` (Phase 8): кнопки «Запросить доступ», System Settings, «Проверить снова».

## Тесты

| Файл | Сценарии |
|------|----------|
| `Phase7CaptureOCRTests.swift` | `OCRResult`, preprocessor JPEG/cancel, permission status, capture cancel |
| `Phase3CaptureRegionUseCaseTests.swift` | fakes с `OCRResult`, cancel forwarding, OCR cancellation |
| `Phase6OpenAIOCRServiceTests.swift` | structured result + lines |

## Критерии выхода (roadmap)

| Критерий | Статус |
|----------|--------|
| Structured `OCRResult` | ✅ |
| `VisionOCRService` / `OpenAIOCRService` boundary | ✅ |
| Image preprocessing isolated | ✅ `OCRImagePreprocessor` |
| OCR cancellation | ✅ |
| OCR off main thread | ✅ |
| ScreenCaptureKit behind `ScreenCapturing` | ✅ `ScreenCaptureKitCaptureService` |
| Hotkey cancel active capture | ✅ |
| Permission actionable UI | ✅ status + request + settings |
| Fakes in tests | ✅ |

## Следующий шаг

**Phase 8 завершена** — см. [Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md). **Phase 9** — testing strategy ([roadmap](project-refactoring-roadmap.md)).

## See Also

- [Refactoring Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md)
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md)
- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md)
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md)
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md)
- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md)
- [Refactoring Phase 5 SQLite Persistence](refactoring-phase-5-sqlite-persistence.md)
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md)
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md)
