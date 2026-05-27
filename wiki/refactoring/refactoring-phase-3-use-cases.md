# Refactoring Phase 3 Use Cases

> Sources: llh project, 2026-05-26
> Raw: [Phase 3 capture use cases completion](../../raw/refactoring/2026-05-26-phase-3-capture-use-cases-completion.md); [Phase 3 format captured text completion](../../raw/refactoring/2026-05-26-phase-3-format-captured-text-completion.md); [Phase 3 manage history use case completion](../../raw/refactoring/2026-05-26-phase-3-manage-history-use-case-completion.md); [Phase 3 manage profiles use case completion](../../raw/refactoring/2026-05-26-phase-3-manage-profiles-use-case-completion.md); [Phase 3 load word study use case completion](../../raw/refactoring/2026-05-26-phase-3-load-word-study-use-case-completion.md); [Phase 3 manage OpenAI settings use case completion](../../raw/refactoring/2026-05-26-phase-3-manage-openai-settings-use-case-completion.md)
> Updated: 2026-05-27

## Overview

Phase 3 («Extract Use Cases Workflow By Workflow») **завершена**. Все 7 use cases зарегистрированы в контейнере. `MainViewModel` (~783 строк) координирует UI, overlay и shortcuts; не вызывает `OpenAIServing`, `SettingsRepository` или `APIKeyRepository` напрямую.

### Use cases в `AppDependencyContainer`

| Use case | OpenAI / infra |
|----------|----------------|
| `RecognizeTextUseCase` | `OCRServing` / `OpenAIOCRServing` → `OCRResult` (Phase 7); `Sendable`, off main actor |
| `CaptureRegionUseCase` | Permission, region, screenshot + recognize |
| `FormatCapturedTextUseCase` | `OpenAIServing.formatRecognizedText` → `OpenAITranslationService` (Phase 6 PR 5) |
| `ManageHistoryUseCase` | `HistoryRepository` |
| `ManageProfilesUseCase` | Профили + `ManageHistoryUseCase` |
| `LoadWordStudyUseCase` | `OpenAIServing.buildWordsStudyData` → `OpenAIStudyService` (Phase 6 PR 5) |
| `ManageOpenAISettingsUseCase` | `SettingsRepository`, `APIKeyRepository`, `fetchModels` |

## Инкремент 1 — capture и recognize

| Файл | Назначение |
|------|------------|
| `Domain/Errors/RegionSelectionError.swift` | Ошибки выделения области (`cancelled`, `noScreen`) |
| `Domain/UseCases/RecognizeTextUseCase.swift` | Local vs AI OCR по `OCREngine`; возвращает `OCRResult` |
| `Domain/UseCases/CaptureRegionUseCase.swift` | Permission → region → screenshot → recognize; `cancelActiveCapture()` |

### CaptureRegionOutcome

| Исход | Смысл |
|-------|--------|
| `permissionDenied` | Нет Screen Recording |
| `selectionCancelled` | Пользователь отменил выделение |
| `noTextFound(image:)` | `OCRResult.isEmpty` |
| `captured(image:text:)` | Успех |

Use case не пишет в историю и не трогает overlay — это остаётся в `MainViewModel.startCaptureFlow`.

### DI (capture)

`AppDependencyContainer` содержит `recognizeTextUseCase` и `captureRegionUseCase`; сборка через `makeCaptureUseCases(ocrService:openAIOCRService:)` — `VisionOCRService` + `OpenAIOCRServing` (Phase 7).

`RegionSelectionService` бросает `RegionSelectionError` (раньше — вложенный `SelectionError`).

## Инкремент 2 — format captured text

| Файл | Назначение |
|------|------------|
| `Domain/UseCases/FormatCapturedTextUseCase.swift` | Preflight + OpenAI format через `OpenAIServing` |

### FormatCapturedTextPreflight

| Исход | Смысл |
|-------|--------|
| `missingAPIKey` | Нет токена |
| `missingModel` | Не выбрана модель |
| `skipped` | Уже готово, processing без retry, или пустой текст |
| `ready` | Можно вызывать `perform` |

- `preflight` — синхронные проверки, без сети
- `perform` — `formatRecognizedText` через `OpenAIServing` (фасад → `OpenAITranslationService`); ошибки пробрасываются в ViewModel

Use case не меняет `formattingStatus`, не пишет историю и не управляет overlay. Граница use case не менялась с Phase 6 PR 5.

### DI (format)

`AppDependencyContainer.formatCapturedTextUseCase` — `FormatCapturedTextUseCase(openAIService:)`.

## Инкремент 3 — manage history

| Файл | Назначение |
|------|------------|
| `Domain/Models/HistorySessionState.swift` | In-memory сессия: profiles, active profile, selected entry |
| `Domain/UseCases/ManageHistoryUseCase.swift` | Load/save, нормализация, CRUD записей, `mutateEntry` |

### Операции ManageHistoryUseCase

| Метод | Назначение |
|-------|------------|
| `loadSession()` | `HistoryRepository.loadStore` + `normalizeLoadedStore` |
| `saveSession(_:)` | Snapshot → `saveStore` |
| `normalizeLoadedStore` | Repair, default profile на индексе 0, валидный `selectedProfileID` |
| `resolveEntrySelectionForSelectedProfile` | Persisted или первая запись |
| `selectEntry` / `deleteEntry` / `insertEntry` | Выбор и CRUD в активном профиле |
| `updateSelectedEntryText` | Текст + сброс format/study |
| `mutateEntry` | Точечные изменения записи по `profileID` + `entryID` |

### Границы (history)

- Use case не трогает SwiftUI, overlay, status messages
- На диске `HistoryStoreSnapshot` без глобального `selectedEntryID` (как раньше)

### DI (history)

`AppDependencyContainer.manageHistoryUseCase` — общий `historyRepository` с контейнером в `live()`.

## Инкремент 4 — manage profiles

| Файл | Назначение |
|------|------------|
| `Domain/UseCases/ManageProfilesUseCase.swift` | Create/select/delete/rename профилей, защита Default (v0.2 inc. 2: rename, delete by ID) |

### ManageProfilesDeleteOutcome

| Исход | Смысл |
|-------|--------|
| `deleted(removedName:)` | Профиль удалён; выбран первый в списке |
| `cannotDeleteDefaultProfile` | Default нельзя удалить |
| `noSelectedProfile` | Нет активного профиля |
| `profileNotFound` | ID не найден (v0.2 inc. 2) |

### ManageProfilesRenameOutcome (v0.2 inc. 2)

| Исход | Смысл |
|-------|--------|
| `renamed(displayName:)` | Имя обновлено и сохранено через VM persist |
| `profileNotFound` | ID не найден |

### Операции ManageProfilesUseCase

| Метод | Назначение |
|-------|------------|
| `normalizedProfileName(from:)` | Trim; пустое имя → `"Новый профиль"` |
| `createProfile` | Insert at 0, select profile, resolve entry |
| `selectProfile` | Смена профиля + resolve/clear entry |
| `renameProfile` | Переименование по ID (v0.2 inc. 2) |
| `deleteProfile` / `deleteSelectedProfile` | Удаление по ID или выбранного; Default защищён |
| `canDeleteProfile` / `canDeleteSelectedProfile` | `false` для Default |

После create/select/delete вызывается `ManageHistoryUseCase.resolveEntrySelectionForSelectedProfile`.

### Границы (profiles)

- Use case не трогает status messages, overlay, `SettingsRepository`
- `setDefaultNewProfileLearningLanguage` при создании профиля — в ViewModel

### DI (profiles)

`AppDependencyContainer.manageProfilesUseCase` — `ManageProfilesUseCase(manageHistoryUseCase:)`.

### MainViewModel после profiles-инкремента

- `historySession` / `applyHistorySession` — мост `@Published` ↔ use cases
- Profiles: `manageProfilesUseCase`; entries: `manageHistoryUseCase`
- Удалён `syncProfileSelectionToEditor` (логика в `selectProfile` + use cases)

## Инкремент 5 — load word study

| Файл | Назначение |
|------|------------|
| `Domain/UseCases/LoadWordStudyUseCase.swift` | Preflight + OpenAI word study через `OpenAIServing` |

### Типы запроса

- `LoadWordStudyRequest` — язык профиля, `profileSupportsWordStudy`, `forceReload`, `formattedText`, `wordsStatus`, `words`
- `LoadWordStudyConfiguration` — `apiKey`, `modelID`

### LoadWordStudyPreflight

| Исход | Смысл |
|-------|--------|
| `missingAPIKey` | Нет токена |
| `missingModel` | Не выбрана модель |
| `skipped` | Профиль без word study, нет formatted text, уже готово/processing без forceReload |
| `ready` | Можно вызывать `perform` |

- `preflight` — синхронные проверки, без сети
- `perform` — `buildWordsStudyData`; ошибки пробрасываются в ViewModel

Use case не меняет `wordsStatus`, не пишет историю и не обновляет `@Published studyMaterials`.

### Границы (word study)

- Phrase/grammar study API удалены в Phase 10 (не были подключены к UI)
- Загрузка только по запросу пользователя (`retryStudyAssistantDataForSelectedEntry` с `forceReload: true`)

### DI (word study)

`AppDependencyContainer.loadWordStudyUseCase` — `LoadWordStudyUseCase(openAIService:)`.

### MainViewModel после word-study-инкремента

- ~799 строк (до инкремента 6)
- `loadStudyMaterial` → preflight/perform use case; helpers `applyWordStudySuccess` / `applyWordStudyFailure`
- `.processing` и persist — в ViewModel после preflight `.ready`
- Settings flow ещё во ViewModel — вынесен в инкременте 6

> **После Phase 4 inc. 4:** `loadStudyMaterial` и `@Published studyMaterials` — в `StudyViewModel`; `LoadWordStudyUseCase` без изменений.

## Инкремент 6 — manage OpenAI settings

| Файл | Назначение |
|------|------------|
| `Domain/UseCases/ManageOpenAISettingsUseCase.swift` | Load/persist settings, validate API key, fetch models |

### Типы

- `OpenAISettingsSnapshot` — startup read: models, selected model, OCR, language, overlay timing
- `ValidateAndSaveAPIKeyPreflight` — `emptyToken`, `ready(trimmedToken:)`
- `RefreshModelsPreflight` — `missingAPIKey`, `ready(trimmedToken:)`
- `FetchAndPersistModelsResult` — models + resolved selected model ID

### Операции ManageOpenAISettingsUseCase

| Метод | Назначение |
|-------|------------|
| `loadSettingsSnapshot()` | Read from repositories; fallback selected model to first cached |
| `hasAPIKey()` / `currentAPIKey()` | Keychain read for UI and other use case configurations |
| `preflightValidateAndSaveAPIKey` / `performValidateAndSaveAPIKey` | Trim, fetch models, save key, cache models, resolve selection |
| `preflightRefreshModels` / `performRefreshModels` | Refresh with stored key |
| `deleteAPIKey()` | Keychain delete |
| `persistSelectedModelID` / `persistOCREngine` / `persistDefaultNewProfileLearningLanguage` | Settings writes |
| `persistTranslationOverlayMinimumDuration` / `persistTranslationOverlaySecondsPerWord` | Clamped overlay timing writes |

### Границы (OpenAI settings)

- Use case не трогает status messages, loading flags, OCR overlay on hotkey
- Token validation через `GET /v1/models` (существующий `OpenAIServing.fetchModels`)

### DI (OpenAI settings)

`AppDependencyContainer.manageOpenAISettingsUseCase` — shared `settingsRepository` и `apiKeyRepository` с контейнером в `live()`.

### MainViewModel после settings-инкремента (финальное состояние Phase 3)

- ~783 строк
- `applySettingsSnapshot(_:)` при init
- Нет прямых зависимостей от `OpenAIServing`, `SettingsRepository`, `APIKeyRepository`
- Capture/format/word study читают API key через `currentAPIKey()`
- Overlay и shortcuts остаются во ViewModel (Phase 4)

> **После Phase 4 inc. 1:** настройки вынесены в `SettingsViewModel` (~685 строк Main). Use case тот же; UI state settings — не в Main.
>
> **После Phase 4 inc. 2:** история/профили в `HistoryViewModel` (~509 строк Main). `ManageHistoryUseCase` / `ManageProfilesUseCase` вызываются из History VM; capture/format/study по-прежнему координирует Main.
>
> **После Phase 4 inc. 4:** захват в `CaptureViewModel`; study в `StudyViewModel`; overlay — `TranslationOverlayCoordinator`; format/editor ещё на Main (~307 строк).
>
> **После Phase 4 inc. 5:** format/editor в `EditorViewModel` → `FormatCapturedTextUseCase`; Main ~157 строк (фасад). См. [Phase 4](refactoring-phase-4-presentation.md).

## Покрытие тестами

`llhTests/Phase3CaptureRegionUseCaseTests.swift` (7 тестов):

- permission denied / selection cancelled / no text / captured
- local vs AI recognize; AI без API key → `OpenAIServiceError.invalidTokenFormat`

`llhTests/Phase3FormatCapturedTextUseCaseTests.swift` (8 тестов):

- preflight: missing key/model, skip (succeeded/processing/empty), ready при forceRetry
- perform: success, propagation `OpenAIServiceError`

`llhTests/Phase3ManageHistoryUseCaseTests.swift` (10 тестов):

- normalize: default profile insert/move, repair processing→failed
- load fallback `selectedProfileID`, delete/insert/resolve selection, update text reset
- save roundtrip, `mutateEntry`

`llhTests/Phase3ManageProfilesUseCaseTests.swift` (12 тестов):

- normalized name; createProfile insert/select
- selectProfile resolve/clear entry
- canDelete false for Default; delete custom/default/no selection
- renameProfile; deleteProfile non-selected / profileNotFound (v0.2 inc. 2)

`llhTests/Phase3LoadWordStudyUseCaseTests.swift` (9 тестов):

- preflight: unsupported profile, missing key/model, skip без formatted text, skip succeeded/processing, ready при forceReload
- perform: success, propagation `OpenAIServiceError`

**Итого Phase 3 unit-тестов:** 60 (7 + 8 + 10 + 12 + 9 + 14).

`llhTests/Phase3ManageOpenAISettingsUseCaseTests.swift` (14 тестов):

- loadSettingsSnapshot: fallback model, stored selection
- hasAPIKey / currentAPIKey
- preflight validate: emptyToken, ready
- perform validate: persist models/key, keep valid selection, fallback model, propagate error
- preflight/perform refresh
- deleteAPIKey
- persist settings with clamping
- resolveSelectedModelID

## Критерии выхода Phase 3 (roadmap)

| Use case | Статус |
|----------|--------|
| `CaptureRegionUseCase` | выполнено |
| `RecognizeTextUseCase` | выполнено (в составе capture) |
| `FormatCapturedTextUseCase` | выполнено |
| `ManageHistoryUseCase` | выполнено |
| `ManageProfilesUseCase` | выполнено |
| `LoadWordStudyUseCase` | выполнено |
| `ManageOpenAISettingsUseCase` | выполнено |

Phase 3 завершена: `MainViewModel` делегирует все перечисленные workflows; use cases покрыты fake-driven тестами.

## Следующий шаг

Phase 3 завершена; **Phases 6–10 завершены** — integration tests в [Phase 9](refactoring-phase-9-testing-strategy.md); cleanup в [Phase 10](refactoring-phase-10-cleanup.md).

## See Also

- [Refactoring Phase 10 Cleanup](refactoring-phase-10-cleanup.md) — phrase/grammar study API removed
- [Refactoring Phase 9 Testing Strategy](refactoring-phase-9-testing-strategy.md) — capture/format/settings integration tests
- [Refactoring Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md) — split ContentView, per-VM status (завершена)
- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md) — `OCRResult`, cancellation, Infrastructure adapters (завершена)
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md) — Phase 6 завершена: HTTP, models, OCR, translation/study, settings/keychain
- [Refactoring Phase 5 SQLite Persistence](refactoring-phase-5-sqlite-persistence.md) — persistence за тем же protocol
- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md) — Phase 4 завершена (все 5 инкрементов)
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — модели и Data/OpenAI границы до use cases
- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md) — протоколы и контейнер
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь MainViewModel
- [v0.2 Product Plan](v0-2-product-plan.md) — `renameProfile` / `deleteProfile(profileID:)` (Increment 2)
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — полный план (архивный snapshot)
