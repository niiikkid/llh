# Phase 3 Manage Profiles Use Case (llh)

> Source: llh repository — Phase 3 fourth increment (ManageProfilesUseCase)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

Fourth increment of Phase 3 («Extract Use Cases Workflow By Workflow») completed. No user-facing behavior changes. Profile create/select/delete and `canDeleteSelectedProfile` moved from `MainViewModel` into `ManageProfilesUseCase`. Entry selection after profile changes delegates to `ManageHistoryUseCase.resolveEntrySelectionForSelectedProfile`. Status messages, `setDefaultNewProfileLearningLanguage`, editor sync, `persistHistory`, study/format, overlay, and settings remain in ViewModel.

## New code artifacts

### Domain — use case

- `llh/Domain/UseCases/ManageProfilesUseCase.swift`
  - `ManageProfilesDeleteOutcome`: `deleted(removedName:)`, `cannotDeleteDefaultProfile`, `noSelectedProfile`
  - `normalizedProfileName(from:)` — trim; empty → `"Новый профиль"`
  - `createProfile(state:named:learningLanguage:)` — insert at 0, select profile, resolve entry
  - `selectProfile(state:profileID:)` — resolve entry or clear `selectedEntryID`
  - `deleteSelectedProfile(state:)` — reject default; select `profiles.first` after removal
  - `canDeleteSelectedProfile(state:)`
  - Depends on `ManageHistoryUseCase` (not `HistoryRepository` directly)

### App — dependency container

- `AppDependencyContainer.manageProfilesUseCase`
- `live()`: `ManageProfilesUseCase(manageHistoryUseCase:)` after shared `manageHistoryUseCase`

### MainViewModel changes

- Injects `manageProfilesUseCase` from container
- `createProfile` / `selectProfile` / `deleteSelectedProfile` / `canDeleteSelectedProfile` delegate to use case via `historySession` / `applyHistorySession`
- Removed `syncProfileSelectionToEditor` (behavior covered by `selectProfile` + use cases)
- `selectProfile` clears editor when no active profile; `showsSessionReadingOverview = false` on select
- ~768 lines

### Tests

- `llhTests/Phase3ManageProfilesUseCaseTests.swift` — 8 tests
  - normalized name placeholder and trim
  - createProfile insert/select
  - selectProfile resolves persisted entry; nil clears selection
  - canDelete false for default
  - delete rejects default; removes custom and selects first
  - delete with no selection → `noSelectedProfile`
- `llhTests/Phase1RepositoryTests.swift` — container init includes `manageProfilesUseCase`

## Boundaries (unchanged product rules)

- Use case does not touch SwiftUI, overlay, shortcuts, status strings, or `SettingsRepository`
- `setDefaultNewProfileLearningLanguage` stays in ViewModel on create (UserDefaults via settings repo)
- Default profile cannot be deleted; same user-visible messages in ViewModel

## Exit criteria (this increment)

| Criterion | Status |
|-----------|--------|
| Profile CRUD in use case with entry selection consistency | done |
| Default profile protected | done |
| MainViewModel does not mutate `profiles` directly for create/select/delete | done |
| Fake-driven tests without user Keychain | done |
| No product behavior change | done |
| Full Phase 3 (all 7 use cases) | not done |

## Remaining Phase 3 work (roadmap order)

1. ~~CaptureRegionUseCase~~ (done)
2. ~~RecognizeTextUseCase~~ (done)
3. ~~FormatCapturedTextUseCase~~ (done)
4. ~~ManageHistoryUseCase~~ (done)
5. ~~ManageProfilesUseCase~~ (done)
6. `LoadWordStudyUseCase`
7. `ManageOpenAISettingsUseCase`

## Verification

```bash
xcodebuild -scheme llh -destination 'platform=macOS' test -only-testing:llhTests/Phase3ManageProfilesUseCaseTests
```
