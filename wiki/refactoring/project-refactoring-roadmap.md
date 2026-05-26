# LLH Project Refactoring Roadmap

> Sources: project audit against Cursor rules
> Archived: 2026-05-26

## Overview

This page is a point-in-time refactoring roadmap for bringing `llh` into alignment with the new Cursor rules. The target is a native macOS SwiftUI/AppKit, local-first application with a clean layered direction: UI -> ViewModels -> UseCases -> Repositories -> Services / Persistence / API. The current project is functional but still organized mostly as a flat `MainViewModel + Services` app. The safest path is an incremental refactor: first stabilize boundaries and tests, then extract domain models and workflows, then split presentation state, then migrate persistence and modernize OpenAI/OCR infrastructure.

## Target Architecture

The desired dependency direction is:

```text
App -> Presentation -> Domain -> Data / Infrastructure

UI -> ViewModels -> UseCases -> Repository/Service protocols -> concrete implementations
```

The target layers should be:

- `App`: app entry point, dependency container, lifecycle wiring, environment setup, shortcut coordinator ownership.
- `Presentation`: SwiftUI views, AppKit bridge controllers, feature ViewModels, UI state models, alert/loading state.
- `Domain`: product models, use cases, repository/service protocols, domain errors, workflow contracts.
- `Data`: concrete repositories, OpenAI client/services, DTOs, request/response mapping, prompt builders.
- `Infrastructure`: Vision OCR adapter, ScreenCaptureKit adapter, Keychain adapter, file system/database client, permission checks, logging.

The refactor should preserve the product boundaries:

- macOS-only native Swift app.
- SwiftUI-first UI with AppKit only for native macOS surfaces such as panels, overlays, selection windows, menu bar, event monitoring and window behavior.
- Local-first history and settings.
- No web frontend, backend, Electron, Docker, mobile targets or browser automation.
- Keep macOS 26.0+ deployment target.
- Keep screenshots in memory unless persistence is explicitly requested.
- Keep OpenAI calls limited to user-selected AI-powered operations.

## Current State Summary

The current project has a small number of Swift files and a large amount of orchestration concentrated in `llh/MainViewModel.swift`. Existing service extraction is useful but incomplete. There are concrete services for OCR, screenshot capture, region selection, screen recording permission, history persistence and OpenAI, but most of them are not behind domain protocols and are constructed directly by the main ViewModel.

Current high-level structure:

- `llh/llhApp.swift`: app entry point that creates one `MainViewModel` and shares it with the main window and menu bar UI.
- `llh/MainViewModel.swift`: central hub for domain models, UI state, settings, capture, OCR routing, formatting, history CRUD, persistence, overlay coordination, keyboard shortcuts and clipboard actions.
- `llh/ContentView.swift`: large main SwiftUI surface with settings and study-related UI embedded in the same file.
- `llh/MenuBarPanelView.swift`: menu bar panel UI.
- `llh/TranslationOverlayService.swift`: AppKit overlay behavior.
- `llh/Services/OCRService.swift`: Vision OCR implementation.
- `llh/Services/ScreenshotService.swift`: ScreenCaptureKit screenshot implementation.
- `llh/Services/RegionSelectionService.swift`: AppKit region selection overlay.
- `llh/Services/ScreenRecordingPermissionService.swift`: Screen Recording permission checks.
- `llh/Services/HistoryPersistenceService.swift`: JSON file persistence.
- `llh/Services/OpenAIService.swift`: OpenAI HTTP, prompts, DTO mapping, settings store and Keychain token store.
- `llhTests/llhTests.swift`: useful tests for formatting, persistence, settings, prompt construction and some domain helpers.
- `llhUITests/`: mostly launch/performance boilerplate.

The existing code already has some good foundations:

- ScreenCaptureKit is used for capture.
- Vision is used for local OCR.
- API token storage is in Keychain, not UserDefaults.
- App Sandbox is enabled.
- History is local.
- There are tests around JSON persistence, settings store behavior and prompt construction.
- OpenAI DTOs are mostly private to `OpenAIService`.
- Browser automation has been removed and must not be reintroduced.

## Main Gaps Against The New Rules

The largest gap is architectural, not feature-level. The project has services, but not a clean layered flow.

Key mismatches:

- `MainViewModel` is a god object and should not receive new independent responsibilities.
- Use cases are absent; user workflows are methods on `MainViewModel`.
- Repository protocols are absent; persistence/settings/keychain are concrete implementations.
- Concrete dependencies are created inside the ViewModel instead of injected.
- Domain models live in `MainViewModel.swift` together with presentation state and migration behavior.
- Prompt fragments and OpenAI-specific behavior leak into domain-facing types.
- `OpenAIService` is too broad: HTTP, prompts, model fetching, AI OCR, formatting, study generation, Keychain and UserDefaults coexist in one file.
- History persistence is a growing JSON file, not a repository-backed database.
- Persistence calls are synchronous and coordinated from the ViewModel.
- `ContentView.swift` is large and mixes multiple feature surfaces.
- Keyboard shortcut registration is owned by `MainViewModel`.
- OCR returns plain text rather than structured OCR result models.
- AI OCR is part of `OpenAIService`, not a distinct `OpenAIOCRService` behind an OCR boundary.
- Permission request logic exists but is not fully integrated into the first-capture UX.
- Tests do not yet cover extracted use cases, repository abstractions, OpenAI response mapping or migration edge cases enough for a larger refactor.

## Refactoring Principles

Every phase should be small, reviewable and behavior-preserving unless explicitly marked as a feature change. The project should move toward the new rules without a single high-risk rewrite.

Principles:

- Introduce protocols before replacing implementations.
- Wrap existing code first, then move behavior behind boundaries.
- Prefer one workflow extraction per PR.
- Preserve user data and never delete old `history.json` during migration.
- Keep JSON history as a backup until a later explicit cleanup.
- Add tests around behavior before moving it.
- Keep UI thin: Views display state and send actions.
- Keep ViewModels as coordinators, not infrastructure owners.
- Keep API/persistence DTOs out of UI.
- Keep OpenAI prompts centralized and tested.
- Do not run full build/test automatically unless the user asks; prepare test targets and note what should be run.

## Phase 0: Baseline And Safety Net

Goal: create enough clarity and characterization coverage to refactor without losing behavior.

Scope:

- Inventory every `@Published` property and public action in `MainViewModel`.
- Group current responsibilities into feature buckets: capture, OCR, translation, history, settings, overlay, shortcuts, study material, profiles/session.
- Map every persistence write call and identify whether it is user-triggered, automatic, startup repair or migration-related.
- Map every OpenAI call and the prompt path used by it.
- Map every UI dependency on `MainViewModel` from `ContentView`, `MenuBarPanelView` and `llhApp`.
- Identify dead or incomplete surfaces such as phrase/grammar study APIs that are not wired to UI.

Tests to add before deeper moves:

- Characterization tests for JSON history load/save roundtrip with multiple profiles.
- Tests for legacy history decoding into the current profile model.
- Tests for interrupted processing state repair on load.
- Tests for default profile invariants.
- Tests for OCR engine setting persistence.
- Tests for overlay timing persistence.
- Tests for prompt construction that is currently assembled indirectly.
- Tests for user-visible error mapping where currently possible without UI automation.

Exit criteria:

- There is a short internal inventory document or code comments are not needed because the mapping is represented in tests and extracted types.
- Existing behavior is covered enough to detect regressions in persistence, settings and prompt construction.
- No production behavior changes yet.

Recommended PR boundary:

- One PR for baseline tests and inventory-only refactor helpers.

## Phase 1: Stabilize Boundaries With Protocols And DI

Goal: introduce architectural seams without replacing implementations.

Add domain-facing protocols:

- `HistoryRepository`
- `SettingsRepository`
- `APIKeyRepository`
- `OCRService` or `OCRServing`
- `ScreenCaptureService` or `ScreenCapturing`
- `RegionSelectionService` or `RegionSelecting`
- `ScreenRecordingPermissionChecking`
- `OpenAIRepository` or a smaller set of OpenAI feature protocols
- `TranslationOverlayCoordinating`
- `ClipboardService` if copy behavior remains outside UI

Initial concrete adapters:

- `JSONHistoryRepository` wrapping `HistoryPersistenceService`.
- `UserDefaultsSettingsRepository` wrapping current settings store.
- `KeychainAPIKeyRepository` wrapping current token store.
- `VisionOCRService` wrapping the current Vision OCR implementation.
- `ScreenCaptureKitService` wrapping the current screenshot service.
- `AppKitRegionSelectionService` wrapping the current region selection service.
- `OpenAIService` temporarily conforming to the relevant OpenAI protocol.

Dependency injection:

- Introduce a small `AppDependencyContainer`.
- Construct concrete services in `llhApp.swift` or an `App` layer factory.
- Inject dependencies into `MainViewModel`.
- Keep default convenience initializers only for previews/tests if useful.
- Replace direct construction inside `MainViewModel` with constructor parameters.

Important constraint:

- Do not change actual storage, OCR, capture or OpenAI behavior in this phase. The purpose is to make the next phases testable.

Tests:

- Add fake repositories/services for ViewModel or use case tests.
- Add tests that verify settings/token/history operations can be exercised without touching real UserDefaults, Keychain or Application Support paths.

Exit criteria:

- `MainViewModel` no longer constructs low-level concrete services.
- OpenAI dependency is consumed through a protocol.
- History/settings/keychain dependencies are consumed through protocols.
- New code can be tested with fakes.

Recommended PR boundaries:

- PR 1: `HistoryRepository` + JSON adapter + tests.
- PR 2: `SettingsRepository` and `APIKeyRepository` + adapters + tests.
- PR 3: OCR/capture/permission protocols + adapters.
- PR 4: OpenAI protocol cleanup and `MainViewModel` constructor injection.

## Phase 2: Extract Domain Models And Errors

Goal: remove domain definitions from `MainViewModel.swift` and make the domain layer independent of UI and infrastructure.

Move into `Domain/Models`:

- Captured text entry model.
- Learning profile model.
- Study material models.
- OCR engine selection if it is product state rather than UI state.
- Overlay timing if it is product/settings state.
- Translation/formatting result models.
- Language-related display models that are not prompt-specific.

Move into `Domain/Errors`:

- User-facing workflow errors.
- Domain validation errors.
- Repository error abstractions where useful.

Keep out of Domain:

- OpenAI request/response DTOs.
- JSON storage-only snapshot types.
- Keychain item names.
- UserDefaults keys.
- ScreenCaptureKit or Vision-specific types.
- Prompt strings and model-specific API instructions.

Handle migration coupling:

- Keep temporary `Codable` compatibility if it is needed for JSON history.
- Prefer moving legacy decode behavior into Data-layer mappers over time.
- Avoid breaking existing `history.json`.

Prompt cleanup:

- Move OpenAI-specific language instructions out of `LearningLanguage`.
- Create `OpenAIPromptBuilder` or feature-specific prompt builders in `Data/OpenAI`.
- Keep prompt construction covered by tests.

Exit criteria:

- `MainViewModel.swift` no longer starts with hundreds of lines of domain model definitions.
- Domain models do not know about OpenAI endpoints, JSON snapshots, UserDefaults or Keychain.
- Prompt construction lives outside domain models.

Recommended PR boundaries:

- PR 1: move pure domain models without changing code.
- PR 2: move persistence snapshot/legacy decode helpers into Data.
- PR 3: extract prompt builder and update tests.

## Phase 3: Extract Use Cases Workflow By Workflow

Goal: move user workflows out of `MainViewModel` into testable domain/application operations.

Extract use cases in this order:

1. `CaptureRegionUseCase`
2. `RecognizeTextUseCase`
3. `FormatCapturedTextUseCase`
4. `ManageHistoryUseCase`
5. `ManageProfilesUseCase`
6. `LoadWordStudyUseCase`
7. `ManageOpenAISettingsUseCase`

### CaptureRegionUseCase

Responsibilities:

- Check Screen Recording permission.
- Request or report missing permission using a permission abstraction.
- Ask region selector for a rectangle.
- Capture screenshot through the capture service.
- Route OCR through local or AI mode.
- Return a domain-level result that the ViewModel can insert into history.

Do not include:

- SwiftUI state mutation.
- Alert text formatting beyond domain error type.
- Direct AppKit overlay lifecycle.
- Direct persistence writes unless the use case explicitly composes with history storage.

### RecognizeTextUseCase

Responsibilities:

- Choose `VisionOCRService` or `OpenAIOCRService` based on settings.
- Enforce local OCR vs AI OCR privacy boundary.
- Validate API key availability for AI OCR.
- Return a structured OCR result, not only a raw string.
- Support cancellation.

### FormatCapturedTextUseCase

Responsibilities:

- Format and translate recognized text with OpenAI.
- Use centralized prompt builder.
- Map OpenAI failures into domain errors.
- Return structured formatted text.
- Respect cancellation.

Open questions:

- Whether overlay display is a separate coordinator triggered by the ViewModel or part of a workflow service.
- Whether formatting should persist automatically or return a result that `ManageHistoryUseCase` persists.

### ManageHistoryUseCase

Responsibilities:

- Add, update, delete and select entries.
- Maintain default profile invariant.
- Normalize loaded history state.
- Coordinate repository writes.

This use case is the bridge toward SQLite migration. It should initially use the JSON-backed `HistoryRepository`.

### ManageProfilesUseCase

Responsibilities:

- Create/delete/select profiles.
- Persist selected profile.
- Protect the default profile from invalid deletion.
- Keep selected entry state consistent when profiles change.

### LoadWordStudyUseCase

Responsibilities:

- Request word-level study material from OpenAI.
- Cache or attach results to the entry.
- Avoid duplicate API calls when study data already exists for the entry.
- Keep phrase/grammar study either explicitly out of scope or promote it to a real feature.

### ManageOpenAISettingsUseCase

Responsibilities:

- Validate/save/delete API key.
- Fetch available models.
- Persist selected model.
- Persist OCR engine selection.
- Persist overlay timing/default language settings.

Exit criteria:

- `MainViewModel` delegates workflows to use cases.
- Use cases are covered with fake services/repositories.
- Main-thread UI updates remain in Presentation.
- OCR/API/database work does not block the main thread.

Recommended PR boundaries:

- One use case per PR.
- Keep old ViewModel method names temporarily if it reduces UI churn.
- Delete or simplify old private helpers only after tests prove behavior.

## Phase 4: Split Presentation Into Feature ViewModels

Goal: make the UI layer match product features and stop using one global ViewModel as the owner of everything.

Introduce feature ViewModels:

- `CaptureViewModel`
- `HistoryViewModel`
- `SettingsViewModel`
- `StudyViewModel`
- `TranslationOverlayViewModel` or `TranslationOverlayCoordinator`
- `MenuBarViewModel`

Possible transitional shape:

- Keep `MainViewModel` as a thin facade that composes feature ViewModels.
- Gradually move `ContentView` and `MenuBarPanelView` to consume feature-specific objects.
- Delete the facade only when the app entry point and views no longer need it.

Move UI state:

- Capture state: `isProcessing`, permission state, capture errors.
- Formatting state: per-entry status, loading flags, retry actions.
- History state: profiles, selected profile, selected entry.
- Settings state: token status, model list, selected model, OCR engine, overlay timing.
- Study state: word study loading/error/results.
- Overlay state: latest translation, visibility, timing.

Extract SwiftUI files:

- `Presentation/Main/ContentView.swift`
- `Presentation/Settings/SettingsView.swift`
- `Presentation/History/HistoryView.swift`
- `Presentation/Capture/CaptureControlsView.swift`
- `Presentation/Study/StudyMaterialsView.swift`
- `Presentation/MenuBar/MenuBarPanelView.swift`
- `Presentation/Overlay` for overlay-facing state if UI is introduced there.

AppKit ownership:

- Keep AppKit selection windows and overlay panels in Infrastructure/Presentation bridge types.
- Do not put AppKit lifecycle code in SwiftUI views.
- Do not keep overlay lifecycle in core domain logic.

Keyboard shortcuts:

- Move registration out of `MainViewModel`.
- Introduce `AppShortcutsCoordinator`.
- Coordinator calls feature actions through protocols or closures.
- Ensure repeated capture hotkey can cancel/stop capture if that feature is implemented later.

Exit criteria:

- `ContentView.swift` is decomposed into feature views.
- Feature ViewModels own feature-specific state.
- `MainViewModel` is either gone or a small composition facade.
- Keyboard shortcut lifecycle is outside history/settings/capture ViewModels.

Recommended PR boundaries:

- PR 1: extract Settings view and SettingsViewModel.
- PR 2: extract History view and HistoryViewModel.
- PR 3: extract CaptureViewModel and shortcut coordinator.
- PR 4: extract Study/Overlay state.
- PR 5: remove or minimize `MainViewModel`.

## Phase 5: History Persistence Migration To SQLite

Goal: move from one growing JSON file to a reliable local database with explicit migrations while preserving user data.

Do not start this phase until:

- `HistoryRepository` exists.
- Current JSON persistence is covered by tests.
- Domain models are separated enough from JSON snapshots.
- Startup load/save flow is behind a use case or repository boundary.

Target storage:

- SQLite-based local persistence by default.
- Repository abstraction hides storage choice from UI.
- Explicit schema versioning.
- Idempotent migrations where possible.
- Migration metadata stored in SQLite or settings, not inferred indirectly.

Migration steps:

1. Define SQLite schema for profiles, entries and study materials.
2. Add database client in Data/Infrastructure.
3. Implement `SQLiteHistoryRepository`.
4. Keep `JSONHistoryRepository` as source and backup.
5. Add `HistoryMigrationService`.
6. On startup, detect whether migration is needed.
7. Read `history.json`.
8. Validate decoded profiles and entries.
9. Write to SQLite transactionally.
10. Verify inserted counts and key invariants.
11. Mark migration complete only after successful verification.
12. Keep `history.json` untouched as backup.
13. Use SQLite repository after migration.

Data rules:

- Never delete old `history.json` during migration.
- Never overwrite user history without a verified replacement.
- Preserve entry IDs, profile IDs, timestamps, recognized text, formatted text and study material.
- Preserve the fact that screenshots are not restored from JSON.
- Repair interrupted `.processing` states consistently.

Tests:

- Fresh install with no history.
- Existing JSON history with one default profile.
- Existing JSON history with multiple profiles.
- Legacy old-format history migration.
- Corrupt JSON handling with user-visible error.
- Idempotent migration when startup runs twice.
- Partial failure does not mark migration complete.
- SQLite repository CRUD.
- Temporary directory/store usage only.

Exit criteria:

- UI and ViewModels do not know whether history is JSON or SQLite.
- Migration is repeatable and safe.
- JSON remains as backup.
- Persistence operations that can grow with data are async.

Recommended PR boundaries:

- PR 1: schema/client and repository tests.
- PR 2: SQLite repository implementation.
- PR 3: migration service with tests.
- PR 4: startup wiring and fallback behavior.
- PR 5: optional cleanup task later, only with explicit user approval.

## Phase 6: OpenAI Integration Modernization

Goal: split OpenAI responsibilities, centralize prompts, strengthen errors and prepare for current API choices.

Do not modernize endpoints blindly. Before changing OpenAI API surface, fetch current documentation through Context7 and make a separate implementation plan.

Target structure:

- `OpenAIHTTPClient`: request execution, authentication header, timeout, cancellation, response decoding.
- `OpenAIModelsService`: model listing and model validation.
- `OpenAITranslationService`: formatting/translation operation.
- `OpenAIOCRService`: AI OCR implementation behind OCR boundary.
- `OpenAIStudyService`: word/phrase/grammar study generation if kept.
- `OpenAIPromptBuilder`: prompt construction and templates.
- DTOs in Data/OpenAI only.
- Domain result models returned to use cases.

Error handling:

- Invalid API key.
- Missing API key.
- Rate limit.
- Offline/network unavailable.
- Timeout.
- Cancellation.
- Malformed response.
- Unsupported model.
- Privacy mode mismatch, such as trying AI OCR while local mode is selected.

Privacy and logging:

- Do not log API keys.
- Do not log full OpenAI payloads by default.
- Do not log full captured text by default.
- Keep local OCR mode respected.
- Send screenshots/text only for explicit AI operations.

Prompt strategy:

- Move prompts into named builders.
- Test prompt construction for each supported operation.
- Keep language-specific formatting rules out of domain enums.
- Avoid manual JSON string construction when `Codable` can represent the request.

Endpoint modernization:

- Evaluate whether to move from Chat Completions to Responses API or structured outputs.
- Treat that as a separate PR after documentation review.
- Keep behavior stable while changing transport.

Exit criteria:

- `OpenAIService.swift` is no longer a monolith.
- OpenAI DTOs do not leak into UI.
- Prompt construction is centralized and tested.
- AI OCR and translation are separate service capabilities.
- Settings/keychain logic is no longer inside OpenAI HTTP implementation.

Recommended PR boundaries:

- PR 1: prompt builder extraction and tests.
- PR 2: HTTP client extraction.
- PR 3: model/settings separation.
- PR 4: AI OCR service extraction.
- PR 5: optional endpoint modernization after documentation review.

## Phase 7: OCR, Capture And Permission Polish

Goal: make capture/OCR flows responsive, cancellable and cleanly separated.

OCR target:

- `OCRService` protocol returns structured `OCRResult`.
- `VisionOCRService` handles Vision-specific logic.
- `OpenAIOCRService` handles AI OCR.
- Image preprocessing is isolated and testable where possible.
- OCR supports cancellation.
- OCR does not block main thread.

Capture target:

- `ScreenCaptureService` protocol hides ScreenCaptureKit details.
- Region selection UI remains AppKit-specific and isolated.
- Capture use case coordinates selection and screenshot.
- Repeated hotkey can cancel/stop an active capture flow if implemented.
- Missing permission maps to actionable UI state.

Permission target:

- Centralize Screen Recording permission handling.
- Avoid repeated permission prompts.
- Use manual System Settings route when appropriate.
- Call request flow intentionally once when product UX requires it.
- UI shows clear, actionable messages.

Tests:

- Use fake region selector.
- Use fake screen capture service.
- Use fake OCR services.
- Test cancellation path.
- Test missing permission path.
- No tests require real Screen Recording permission or real screen contents.

Exit criteria:

- UI does not perform OCR, capture, permission checks or prompt construction.
- Capture/OCR behavior is testable with fakes.
- Long-running image/OCR work stays off the main thread.

## Phase 8: UI Decomposition And State Clarity

Goal: make SwiftUI views declarative and reduce large files.

Work items:

- Split `ContentView.swift` into feature views.
- Move settings sheets/tabs into `Presentation/Settings`.
- Move history list/detail into `Presentation/History`.
- Move study material views into `Presentation/Study`.
- Move capture controls/status into `Presentation/Capture`.
- Replace broad `statusMessage` with feature-specific alert/loading state.
- Introduce simple `ViewState`, `LoadingState` and `AlertState` where useful.
- Remove duplicated display logic for primary line/pinyin/translation ordering.
- Keep AppKit bridges outside SwiftUI views except for focused wrappers.

Presentation rules:

- Views render state and send user actions.
- Views do not call OpenAI, OCR, persistence, Keychain or UserDefaults.
- Views do not contain business rules.
- ViewModels publish simple state and actions.
- UI updates occur on `MainActor`.

Exit criteria:

- Main UI files are smaller and feature-oriented.
- User-facing states are explicit.
- Duplicate display logic is consolidated.
- Settings/history/study/capture can evolve independently.

## Phase 9: Testing Strategy

Goal: align test coverage with the new architecture and refactor risk.

Unit test priorities:

- Domain use cases.
- Repository implementations.
- JSON-to-SQLite migration.
- OpenAI prompt builders.
- OpenAI request/response mapping.
- OCR behavior through mocks.
- Settings repository.
- Keychain wrapper through an injectable abstraction or mock.
- Permission error mapping.
- Formatting/session display helpers.

Integration-style tests:

- Capture workflow with fake permission/region/capture/OCR services.
- Format workflow with fake OpenAI service.
- Startup history load and migration path with temporary stores.
- Settings model selection/token flow with fake stores.

UI tests:

- Keep UI tests limited and stable.
- Avoid real screen capture.
- Avoid live OpenAI network.
- Cover basic launch, settings presence, permission banner behavior if it can be injected.

Rules:

- Unit tests must not call real OpenAI API.
- Unit tests must not require real Screen Recording permission.
- Unit tests must not depend on user Keychain.
- Persistence tests use temporary directories/stores.
- Do not add flaky tests depending on the user's current screen.
- Agent should not run full `xcodebuild test` or build commands unless explicitly requested.

Exit criteria:

- Each extracted use case has focused tests.
- Each repository has focused tests.
- Migration has failure and idempotency tests.
- OpenAI prompt/request mapping is tested without network.

## Phase 10: Cleanup And Product Decisions

Goal: remove dead code and decide which unfinished product surfaces should become real features.

Decisions needed:

- Keep or remove phrase study generation.
- Keep or remove grammar study generation.
- Whether word-click translation becomes a new feature module.
- Whether session vocabulary aggregation becomes a new feature module.
- Whether cost/token usage tracking becomes part of OpenAI usage repository.
- Whether speech/pronunciation becomes a separate audio feature.
- Whether repeated capture hotkey should cancel selection, stop processing or both.

Cleanup work:

- Delete dead code only after confirming it is not part of near-term roadmap.
- Remove duplicate formatting/display helpers.
- Remove compatibility shims only after migration is complete and backed up.
- Keep cleanup PRs separate from behavior-changing PRs.

Exit criteria:

- No unused OpenAI study paths remain without product intent.
- No obsolete persistence path is removed without explicit approval.
- Large old files are reduced or deleted after ownership moves.

## Suggested Milestone Plan

### Milestone A: Refactor Readiness

Includes:

- Baseline tests.
- Protocol boundaries.
- Dependency container.
- Existing implementations wrapped, not replaced.

Outcome:

- The app behaves the same, but dependencies are injectable and the next work is testable.

### Milestone B: MainViewModel Reduction

Includes:

- Domain model extraction.
- Use cases for capture, recognition, formatting and history.
- Feature ViewModels for settings/history/capture.

Outcome:

- `MainViewModel` becomes a small coordinator or disappears.

### Milestone C: Persistence Hardening

Includes:

- SQLite repository.
- Migration service.
- Startup migration.
- JSON backup retained.

Outcome:

- History is local-first but no longer a fragile growing JSON file.

### Milestone D: OpenAI/OCR Hardening

Includes:

- Split OpenAI client/services.
- Centralized prompts.
- `VisionOCRService` and `OpenAIOCRService`.
- Better error/cancellation handling.

Outcome:

- AI and local flows are cleanly separated, testable and privacy-aware.

### Milestone E: UI And Product Polish

Includes:

- Smaller SwiftUI feature views.
- Explicit loading/error state.
- Permission UX cleanup.
- Dead code cleanup or feature decisions.

Outcome:

- The codebase matches the new rules and is ready for new features without expanding old monoliths.

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| `MainViewModel` is central to app behavior | High chance of regressions during split | Extract one workflow at a time, keep facade temporarily, add fake-driven tests |
| History migration can lose user data | Critical | Keep JSON backup, verify migration before marking complete, use transactions, add idempotency tests |
| Domain models currently carry Codable/migration behavior | Medium | Move storage snapshots/mappers gradually; preserve decoding compatibility until SQLite is verified |
| OpenAI behavior can change while refactoring | Medium | Separate prompt/client extraction from endpoint modernization; fetch current docs before API changes |
| Capture/OCR flows depend on macOS permissions | Medium | Use fakes in tests; keep permission UX centralized; avoid tests requiring real permissions |
| Async refactor can introduce races | Medium | Use structured concurrency, task handles and cancellation; keep UI state on `MainActor` |
| Settings and token storage are mixed with OpenAI service | Medium | Extract settings/keychain repositories before OpenAI client split |
| Dead phrase/grammar APIs obscure ownership | Low to medium | Decide whether to remove or promote to feature before final cleanup |
| Large UI files hide business rules | Medium | Split views after use cases exist, not before behavior is protected |

## First Five Concrete PRs

1. Add baseline characterization tests for history/settings/prompt behavior and document current `MainViewModel` responsibilities in test names or small comments.
2. Introduce `HistoryRepository` and `JSONHistoryRepository` wrapping `HistoryPersistenceService`.
3. Introduce `SettingsRepository` and `APIKeyRepository` wrapping UserDefaults and Keychain stores.
4. Add `AppDependencyContainer` and inject current concrete services into `MainViewModel`.
5. Extract pure domain models from `MainViewModel.swift` into `Domain/Models` without changing behavior.

These PRs are intentionally conservative. They make the system movable before touching risky persistence, OpenAI endpoints or large UI decomposition.

## Definition Of Done For The Refactor

The project can be considered aligned with the new rules when:

- New features do not require adding unrelated responsibilities to `MainViewModel`.
- UI views do not call OpenAI, OCR, persistence, UserDefaults or Keychain directly.
- ViewModels coordinate use cases and publish UI state.
- Use cases express user workflows.
- Repository/service protocols live close to Domain.
- Concrete OpenAI, persistence, Keychain, Vision and ScreenCaptureKit implementations live in Data/Infrastructure.
- DTOs and database entities do not leak into UI.
- History is behind `HistoryRepository` and migrated safely from JSON to a local database.
- OpenAI prompts and request mapping are centralized and tested.
- Local OCR and AI OCR are separate implementations behind the same OCR boundary.
- Permission errors map to actionable UI state.
- Tests cover use cases, repositories, migrations and OpenAI mapping without live network, user Keychain or real Screen Recording permission.
- Browser automation remains absent.
- macOS 26.0+ remains unchanged.
