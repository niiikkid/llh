# Phase 3 Capture And Recognize Use Cases (llh)

> Source: llh repository — Phase 3 first increment (CaptureRegionUseCase, RecognizeTextUseCase)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

First increment of Phase 3 («Extract Use Cases Workflow By Workflow») completed. No user-facing behavior changes. Capture flow (permission → region selection → screenshot → OCR) moved from `MainViewModel` into domain use cases. History insertion, formatting, overlay, and persistence remain in `MainViewModel`.

## New code artifacts

### Domain — errors

- `llh/Domain/Errors/RegionSelectionError.swift` — `cancelled`, `noScreen` (moved from nested `RegionSelectionService.SelectionError`)

### Domain — use cases

- `llh/Domain/UseCases/RecognizeTextUseCase.swift` — routes local `OCRServing` vs AI `OpenAIServing.recognizeTextInImage`; `RecognizeTextConfiguration`
- `llh/Domain/UseCases/CaptureRegionUseCase.swift` — orchestrates permission, region, capture, recognize; `CaptureRegionConfiguration`, `CaptureRegionOutcome`

### CaptureRegionOutcome cases

- `permissionDenied` — no Screen Recording permission
- `selectionCancelled` — user cancelled region selection
- `noTextFound(image:)` — OCR returned empty string
- `captured(image:text:)` — success with image and recognized text

### App — dependency container

- `AppDependencyContainer` exposes `recognizeTextUseCase`, `captureRegionUseCase`
- `static func makeCaptureUseCases(...)` — shared factory for `live()` and tests

### MainViewModel changes

- `startCaptureFlow` delegates to `captureRegionUseCase.execute(configuration:)`
- Maps `CaptureRegionOutcome` to UI state (status messages, overlay, history insert, `formatEntryText`)
- Removed direct use of `regionSelectionService`, `screenshotService`, `ocrService` for capture
- `recognizeText(in:)` private helper removed
- `ensureScreenRecordingPermission()` inlined into outcome handling via use case
- ~721 lines (down from ~744 after Phase 2)

### Service change

- `RegionSelectionService` throws `RegionSelectionError` instead of nested `SelectionError`

### Tests

- `llhTests/Phase3CaptureRegionUseCaseTests.swift` — fakes for permission/region/capture/OCR/OpenAI; 7 tests
- `llhTests/Phase1RepositoryTests.swift` — `AppDependencyContainer` init updated for use cases
- `llhTests/llhTests.swift` — `@MainActor` on `sessionReadingCopy_plainText_joinsBlocksWithBlankLineAndPlaceholders`

## Exit criteria (this increment)

| Criterion | Status |
|-----------|--------|
| Capture workflow testable without real screen/permissions | done |
| MainViewModel does not call region/screenshot/OCR directly for capture | done |
| No product behavior change | done |
| Full Phase 3 (all 7 use cases) | not done |

## Remaining Phase 3 work (roadmap order)

1. ~~CaptureRegionUseCase~~ (done)
2. ~~RecognizeTextUseCase~~ (done, composed by capture)
3. `FormatCapturedTextUseCase`
4. `ManageHistoryUseCase`
5. `ManageProfilesUseCase`
6. `LoadWordStudyUseCase`
7. `ManageOpenAISettingsUseCase`

## Verification

```bash
xcodebuild -scheme llh -destination 'platform=macOS' test -only-testing:llhTests/Phase3CaptureRegionUseCaseTests
```

All 7 Phase 3 tests passed on 2026-05-26.
