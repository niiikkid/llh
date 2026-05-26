# Phase 3 Format Captured Text Use Case (llh)

> Source: llh repository — Phase 3 second increment (FormatCapturedTextUseCase)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

Second increment of Phase 3 («Extract Use Cases Workflow By Workflow») completed. No user-facing behavior changes. OpenAI text formatting logic moved from `MainViewModel.formatEntryText` into `FormatCapturedTextUseCase`. History updates, `formattingStatus`, overlay, `isFormattingRecognizedText`, and `persistHistory` remain in `MainViewModel`.

## New code artifacts

### Domain — use case

- `llh/Domain/UseCases/FormatCapturedTextUseCase.swift`
  - `FormatCapturedTextRequest` — raw text, target language, forceRetry, current formatting status and formatted text
  - `FormatCapturedTextConfiguration` — apiKey, modelID
  - `FormatCapturedTextPreflight` — `missingAPIKey`, `missingModel`, `skipped`, `ready`
  - `preflight(request:configuration:)` — sync validation and skip rules (no network)
  - `perform(request:configuration:)` — calls `OpenAIServing.formatRecognizedText`

### App — dependency container

- `AppDependencyContainer` exposes `formatCapturedTextUseCase`
- Built in `live()` as `FormatCapturedTextUseCase(openAIService: openAIService)`

### MainViewModel changes

- `formatEntryText` delegates preflight/perform to use case
- Helpers: `applyFormattingSuccess`, `applyFormattingFailure`, `clearOverlayAwaitingFormat`, `beginFormattingEntry`, `endFormattingEntry`
- `.processing` and `isFormattingRecognizedText` set in ViewModel **after** preflight returns `.ready`, before `perform`
- Does not call `openAIService.formatRecognizedText` directly for entry formatting
- ~746 lines (helpers add lines vs prior ~721; formatting logic moved out)

### Tests

- `llhTests/Phase3FormatCapturedTextUseCaseTests.swift` — 8 tests with `ConfigurableFakeOpenAIServing`
  - preflight: missing API key, missing model, skip when succeeded/processing/empty, ready on forceRetry
  - perform: success, propagates `OpenAIServiceError`
- `llhTests/Phase1RepositoryTests.swift` — `AppDependencyContainer` init includes `formatCapturedTextUseCase`

## Preflight skip rules (unchanged behavior)

- Missing API key or model → ViewModel shows status/overlay messages (no `.processing`)
- Already succeeded with content and not forceRetry → skip
- Already processing and not forceRetry → skip
- Empty/whitespace raw text → skip
- forceRetry bypasses succeeded skip

## Exit criteria (this increment)

| Criterion | Status |
|-----------|--------|
| Format workflow testable with fake `OpenAIServing` | done |
| MainViewModel does not call `formatRecognizedText` directly | done |
| Processing UI state still coordinated in ViewModel | done |
| No product behavior change | done |
| Full Phase 3 (all 7 use cases) | not done |

## Remaining Phase 3 work (roadmap order)

1. ~~CaptureRegionUseCase~~ (done)
2. ~~RecognizeTextUseCase~~ (done)
3. ~~FormatCapturedTextUseCase~~ (done)
4. `ManageHistoryUseCase`
5. `ManageProfilesUseCase`
6. `LoadWordStudyUseCase`
7. `ManageOpenAISettingsUseCase`

## Verification

```bash
xcodebuild -scheme llh -destination 'platform=macOS' test -only-testing:llhTests/Phase3FormatCapturedTextUseCaseTests
```

All 8 Phase 3 format tests passed on 2026-05-26.
