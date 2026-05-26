# Phase 3 Manage History Use Case (llh)

> Source: llh repository — Phase 3 third increment (ManageHistoryUseCase)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

Third increment of Phase 3 («Extract Use Cases Workflow By Workflow») completed. No user-facing behavior changes. History load/save, entry CRUD, selection resolution, and entry mutations moved from `MainViewModel` into `ManageHistoryUseCase`. Profile create/delete/select remain in `MainViewModel` (planned `ManageProfilesUseCase`). Overlay, status messages, editor sync, and study/format UI coordination remain in ViewModel.

## New code artifacts

### Domain — session model

- `llh/Domain/Models/HistorySessionState.swift`
  - In-memory: `profiles`, `selectedProfileID`, `selectedEntryID`
  - Helpers: `selectedProfileIndex`, `selectedEntryIndex`, `profileIndex(for:)`, `entryIndex(profileID:entryID:)`

### Domain — use case

- `llh/Domain/UseCases/ManageHistoryUseCase.swift`
  - `loadSession()` / `saveSession(_:)` via `HistoryRepository`
  - `normalizeLoadedStore(_:)` — `HistoryEntryLoadRepair.repairProfile`, default profile at index 0, valid `selectedProfileID`
  - `resolveEntrySelectionForSelectedProfile(state:)` — persisted or first entry
  - `selectEntry`, `deleteEntry`, `insertEntry`, `updateSelectedEntryText`
  - `mutateEntry(profileID:entryID:body:)` — formatting/study field updates by stable IDs

### App — dependency container

- `AppDependencyContainer.manageHistoryUseCase`
- `live()` shares one `JSONHistoryRepository` instance between container field and use case

### MainViewModel changes

- Replaces direct `historyRepository` with `manageHistoryUseCase`
- `historySession` / `applyHistorySession(_:)` bridge `@Published` state
- `loadHistory`, `persistHistory`, `deleteSelectedEntry`, `selectEntry`, `updateSelectedText`, capture insert, `syncProfileSelectionToEditor` delegate to use case
- `mutateHistoryEntry` wraps `mutateEntry` for format/study persistence paths
- `createProfile`, `deleteSelectedProfile`, `selectProfile` still mutate `profiles` directly + `persistHistory()`
- ~778 lines

### Tests

- `llhTests/Phase3ManageHistoryUseCaseTests.swift` — 10 tests
  - normalize: missing default profile, default moved to index 0, repair processing→failed
  - load fallback when `selectedProfileID` nil
  - deleteEntry selection, insertEntry prepend, resolve entry selection, updateSelectedEntryText reset
  - save roundtrip, mutateEntry
- `llhTests/Phase1RepositoryTests.swift` — `AppDependencyContainer` init includes `manageHistoryUseCase`

## Boundaries (unchanged product rules)

- Use case does not touch SwiftUI, overlay, shortcuts, or status strings
- `HistoryStoreSnapshot` on disk still excludes `selectedEntryID` (per-profile `selectedEntryID` on `LearningProfile` only)
- `HistoryEntryLoadRepair` remains pure; called from `normalizeLoadedStore`

## Exit criteria (this increment)

| Criterion | Status |
|-----------|--------|
| Load/save through use case with invariants | done |
| Entry delete/select/insert/text update in use case | done |
| Format/study entry mutations via `mutateEntry` | done |
| MainViewModel does not call `historyRepository` directly | done |
| Fake-driven tests without user Keychain | done |
| No product behavior change | done |
| Full Phase 3 (all 7 use cases) | not done |

## Remaining Phase 3 work (roadmap order)

1. ~~CaptureRegionUseCase~~ (done)
2. ~~RecognizeTextUseCase~~ (done)
3. ~~FormatCapturedTextUseCase~~ (done)
4. ~~ManageHistoryUseCase~~ (done)
5. `ManageProfilesUseCase`
6. `LoadWordStudyUseCase`
7. `ManageOpenAISettingsUseCase`

## Verification

```bash
xcodebuild -scheme llh -destination 'platform=macOS' test -only-testing:llhTests/Phase3ManageHistoryUseCaseTests
```
