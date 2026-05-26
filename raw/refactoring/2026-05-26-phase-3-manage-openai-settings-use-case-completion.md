# Phase 3 Manage OpenAI Settings Use Case (llh)

> Source: llh repository — Phase 3 sixth increment (ManageOpenAISettingsUseCase)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

Sixth and final increment of Phase 3 («Extract Use Cases Workflow By Workflow») completed. No user-facing behavior changes. OpenAI settings workflow moved from `MainViewModel` into `ManageOpenAISettingsUseCase`. Status messages, loading flags, OCR overlay on hotkey switch, and `@Published` settings state remain in `MainViewModel`.

## New code artifacts

### Domain — use case

- `llh/Domain/UseCases/ManageOpenAISettingsUseCase.swift`
  - `OpenAISettingsSnapshot` — cached models, selected model, OCR engine, default language, overlay timing
  - `ValidateAndSaveAPIKeyPreflight` — `emptyToken`, `ready(trimmedToken:)`
  - `RefreshModelsPreflight` — `missingAPIKey`, `ready(trimmedToken:)`
  - `FetchAndPersistModelsResult` — models + resolved selected model ID
  - `loadSettingsSnapshot()` — startup read from repositories with first-model fallback
  - `preflight` / `perform` pairs for validate-save and refresh
  - `deleteAPIKey()`, persist helpers for model/OCR/language/overlay settings
  - `resolveSelectedModelID(models:currentSelectedModelID:)` — keep valid selection or first model

### App — dependency container

- `AppDependencyContainer` exposes `manageOpenAISettingsUseCase`
- Built in `live()` with shared `settingsRepository` and `apiKeyRepository` instances

### MainViewModel changes

- Removed direct `openAIService`, `settingsRepository`, `apiKeyRepository` dependencies
- `applySettingsSnapshot(_:)` applies startup settings from use case
- Settings actions delegate to use case; status messages stay in ViewModel
- Capture/format/word study read API key via `manageOpenAISettingsUseCase.currentAPIKey()`
- ~779 lines after extraction

### Tests

- `llhTests/Phase3ManageOpenAISettingsUseCaseTests.swift` — 14 tests with in-memory repositories and `SettingsFakeOpenAIServing`
- `llhTests/Phase1RepositoryTests.swift` — container init includes `manageOpenAISettingsUseCase`

## OpenAI API validation

Token validation uses existing `OpenAIServing.fetchModels` → `GET https://api.openai.com/v1/models` with `Authorization: Bearer` (aligned with OpenAI API docs via Context7, 2026-05-26).

## Exit criteria (Phase 3 complete)

| Criterion | Status |
|-----------|--------|
| All 7 roadmap use cases extracted | done |
| MainViewModel does not call `OpenAIServing` directly | done |
| Settings/keychain/model fetch testable with fakes | done |
| No product behavior change | done |

## Verification

```bash
xcodebuild -scheme llh -destination 'platform=macOS' test -only-testing:llhTests/Phase3ManageOpenAISettingsUseCaseTests
```
