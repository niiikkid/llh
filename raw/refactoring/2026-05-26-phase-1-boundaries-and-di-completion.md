# Phase 1 Boundaries And DI Completion (llh)

> Source: llh repository — Phase 1 implementation (Domain/Data repositories, AppDependencyContainer, MainViewModel injection)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

Phase 1 of the refactoring roadmap ("Stabilize Boundaries With Protocols And DI") was completed. No user-facing behavior changes. Existing `HistoryPersistenceService`, `OpenAISettingsStore`, `KeychainOpenAITokenStore`, and capture/OCR services are wrapped behind protocols; `MainViewModel` receives dependencies via `AppDependencyContainer`.

## New code artifacts

### Domain — repository protocols

- `llh/Domain/Repositories/HistoryRepository.swift` — `loadStore()` / `saveStore(_:)`
- `llh/Domain/Repositories/SettingsRepository.swift` — model, language, OCR engine, overlay timing, cached models
- `llh/Domain/Repositories/APIKeyRepository.swift` — `loadAPIKey()` / `saveAPIKey()` / `deleteAPIKey()`

### Domain — capture/OCR service protocols

- `llh/Domain/Services/CaptureServiceProtocols.swift`
  - `ScreenRecordingPermissionChecking`
  - `RegionSelecting` (class-bound)
  - `ScreenCapturing`
  - `OCRServing` (local OCR; distinct from `OpenAIServing`)

### Data — concrete adapters

- `llh/Data/Repositories/JSONHistoryRepository.swift` — wraps `HistoryPersistenceService`
- `llh/Data/Repositories/UserDefaultsSettingsRepository.swift` — wraps `OpenAISettingsStore`
- `llh/Data/Repositories/KeychainAPIKeyRepository.swift` — wraps `OpenAITokenStoring` / `KeychainOpenAITokenStore`

### App — dependency container

- `llh/App/AppDependencyContainer.swift` — `@MainActor`, explicit `init(...)`, `static func live()`, `makeMainViewModel()`

### Tests

- `llhTests/Phase1RepositoryTests.swift` — repository roundtrips, in-memory token store, injected `MainViewModel` smoke test

## MainViewModel wiring changes

Before: `MainViewModel()` constructed `HistoryPersistenceService`, `OpenAISettingsStore`, `KeychainOpenAITokenStore`, `OCRService`, `ScreenshotService`, `RegionSelectionService`, `ScreenRecordingPermissionService`, `OpenAIService`, `TranslationOverlayService` internally.

After: `MainViewModel(dependencies: AppDependencyContainer)` assigns protocol-typed dependencies from the container. `settingsRepository` is `var` (existential mutation for `{ get set }` settings). History load/save uses `historyRepository`. Token/settings use `apiKeyRepository` / `settingsRepository`.

Entry points:

- `llhApp`: `AppDependencyContainer.live().makeMainViewModel()`
- `ContentView` preview: same pattern

`OpenAIServing` already existed; `MainViewModel` now stores `openAIService: OpenAIServing` from injection.

## Intentionally unchanged

- `HistoryPersistenceService` implementation and JSON file path/behavior
- `OpenAISettingsStore` / Keychain storage keys and semantics
- Capture, OCR, OpenAI HTTP, overlay behavior
- Domain models still live in `MainViewModel.swift` (Phase 2)
- `TranslationOverlayService` remains concrete in the container (no overlay protocol yet)

## Phase 1 exit criteria (roadmap)

| Criterion | Status |
|-----------|--------|
| `MainViewModel` no longer constructs low-level concrete services | done |
| OpenAI consumed through `OpenAIServing` | done |
| History/settings/keychain through repository protocols | done |
| New code testable with fakes | done (`Phase1RepositoryTests`, injectable container) |

## Next step (roadmap)

Phase 2: extract domain models and errors from `MainViewModel.swift` into `Domain/Models` and `Domain/Errors` without behavior changes.
