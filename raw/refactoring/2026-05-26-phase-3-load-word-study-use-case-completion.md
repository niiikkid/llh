# Phase 3 Load Word Study Use Case (llh)

> Source: llh repository — Phase 3 fifth increment (LoadWordStudyUseCase)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

Fifth increment of Phase 3 («Extract Use Cases Workflow By Workflow») completed. No user-facing behavior changes. Word-level study OpenAI logic moved from `MainViewModel.loadStudyMaterial` into `LoadWordStudyUseCase`. History updates, `wordsStatus`, `@Published studyMaterials`, and `persistHistory` remain in `MainViewModel`.

## New code artifacts

### Domain — use case

- `llh/Domain/UseCases/LoadWordStudyUseCase.swift`
  - `LoadWordStudyRequest` — target language, profile word-study support, forceReload, formatted text, current words status/payload
  - `LoadWordStudyConfiguration` — apiKey, modelID
  - `LoadWordStudyPreflight` — `missingAPIKey`, `missingModel`, `skipped`, `ready`
  - `preflight(request:configuration:)` — sync validation and skip rules (no network)
  - `perform(request:configuration:)` — calls `OpenAIServing.buildWordsStudyData`

### App — dependency container

- `AppDependencyContainer` exposes `loadWordStudyUseCase`
- Built in `live()` as `LoadWordStudyUseCase(openAIService: openAIService)`

### MainViewModel changes

- `loadStudyMaterial` delegates preflight/perform to use case
- Helpers: `applyWordStudySuccess`, `applyWordStudyFailure`, `syncStudyMaterialsToEditorIfSelected`
- `.processing` set in ViewModel **after** preflight returns `.ready`, before `perform`
- Does not call `openAIService.buildWordsStudyData` directly for entry word study
- `openAIService` still used for `fetchModels` in settings flow

### Tests

- `llhTests/Phase3LoadWordStudyUseCaseTests.swift` — 9 tests with `WordStudyFakeOpenAIServing`
  - preflight: unsupported profile (skipped), missing API key/model, skip without formatted text, skip when succeeded/processing, ready on forceReload
  - perform: success, propagates `OpenAIServiceError`
- `llhTests/Phase1RepositoryTests.swift` — `AppDependencyContainer` init includes `loadWordStudyUseCase`

## Preflight skip rules (unchanged behavior)

- Profile does not support word study → silent skip
- Missing API key or model → ViewModel shows status messages (no `.processing`)
- No formatted text with content → silent skip
- Already succeeded with content and not forceReload → skip
- Already processing and not forceReload → skip
- forceReload bypasses succeeded/processing skip

## Exit criteria (this increment)

| Criterion | Status |
|-----------|--------|
| Word study workflow testable with fake `OpenAIServing` | done |
| MainViewModel does not call `buildWordsStudyData` directly | done |
| Processing/history/UI state still coordinated in ViewModel | done |
| No product behavior change | done |
| Full Phase 3 (all 7 use cases) | not done |

## Remaining Phase 3 work (roadmap order)

1. ~~CaptureRegionUseCase~~ (done)
2. ~~RecognizeTextUseCase~~ (done)
3. ~~FormatCapturedTextUseCase~~ (done)
4. ~~ManageHistoryUseCase~~ (done)
5. ~~ManageProfilesUseCase~~ (done)
6. ~~LoadWordStudyUseCase~~ (done)
7. `ManageOpenAISettingsUseCase`

## Verification

```bash
xcodebuild -scheme llh -destination 'platform=macOS' test -only-testing:llhTests/Phase3LoadWordStudyUseCaseTests
```
