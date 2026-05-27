# Refactoring Phase 1 Boundaries And DI

> Sources: llh project, 2026-05-26
> Raw: [Phase 1 boundaries and DI completion](../../raw/refactoring/2026-05-26-phase-1-boundaries-and-di-completion.md)
> Updated: 2026-05-27

## Overview

Phase 1 («Stabilize Boundaries With Protocols And DI») завершена: введены repository- и service-протоколы, адаптеры над существующими реализациями и `AppDependencyContainer` для сборки зависимостей. Поведение приложения для пользователя не менялось. `MainViewModel` больше не создаёт инфраструктуру внутри себя. Phase 2–5: `HistoryRepository` реализован как `JSONHistoryRepository` + `SQLiteHistoryRepository`; live wiring — `HistoryRepositoryBootstrap` — см. [Phase 5](refactoring-phase-5-sqlite-persistence.md). Phase 4 композирует feature VMs и `AppShortcutsCoordinator` — см. [Phase 4](refactoring-phase-4-presentation.md).

## Направление зависимостей

```text
llhApp → AppDependencyContainer.live() → MainViewModel(dependencies:)
         └─ HistoryRepository / SettingsRepository / APIKeyRepository
         └─ ScreenRecordingPermissionChecking, RegionSelecting, ScreenCapturing, OCRServing
         └─ OpenAIServing, TranslationOverlayService (concrete)
```

Протоколы живут в `llh/Domain/`, реализации-обёртки — в `llh/Data/`, контейнер — в `llh/App/`.

## Репозитории

| Протокол | Реализация | Оборачивает |
|----------|------------|-------------|
| `HistoryRepository` | `JSONHistoryRepository` | `HistoryPersistenceService` |
| `SettingsRepository` | `UserDefaultsSettingsRepository` | `OpenAISettingsStore` (`Data/OpenAI/`, Phase 6 PR 6) |
| `APIKeyRepository` | `KeychainAPIKeyRepository` | `OpenAITokenStoring` / `KeychainOpenAITokenStore` (`Data/OpenAI/`, Phase 6 PR 6) |

`MainViewModel` после Phase 1 напрямую использовал repositories; после Phase 3 — через use cases (`ManageHistoryUseCase`, `ManageOpenAISettingsUseCase` и др.). Настройки и токен на границе Domain: `SettingsRepository`, `APIKeyRepository` (`loadAPIKey` вместо `loadToken`).

## Протоколы capture/OCR

В `CaptureServiceProtocols.swift`:

- `ScreenRecordingPermissionChecking` ← `ScreenRecordingPermissionService`
- `RegionSelecting` ← `RegionSelectionService` (`AnyObject`, `@MainActor` class)
- `ScreenCapturing` ← `ScreenCaptureKitCaptureService` (`Infrastructure/Capture/`, Phase 7)
- `OCRServing` ← `VisionOCRService` (`Infrastructure/OCR/`, Phase 7; локальный OCR, не `OpenAIServing`)
- `ScreenRecordingPermissionChecking` → `permissionStatus` (`ScreenRecordingPermissionStatus`, Phase 7)

## AppDependencyContainer

- `@MainActor struct` с явным `init(...)` без default-аргументов (из-за MainActor-isolated сервисов).
- `static func live()` — production-граф зависимостей.
- `makeMainViewModel()` — фабрика `MainViewModel`.
- Use cases (Phase 3 + v0.2 inc. 5): `recognizeTextUseCase`, `captureRegionUseCase` (`makeCaptureUseCases`), `formatCapturedTextUseCase`, `manageHistoryUseCase`, `manageProfilesUseCase`, `loadWordStudyUseCase`, `loadGrammarStudyUseCase`, `manageOpenAISettingsUseCase`.
- **Phase 6 (завершена):** `live()` — один `OpenAIHTTPClient` (timeout 120s), `OpenAIOCRService` + `OpenAIService(httpClient:ocrService:)` (чистый фасад); `makeCaptureUseCases(..., openAIOCRService:)` для `RecognizeTextUseCase`. Settings/keychain types — `Data/OpenAI/`, не в `OpenAIService.swift` (см. [Phase 6](refactoring-phase-6-openai-integration.md)).
- **Phase 7 (завершена):** `VisionOCRService` + `ScreenCaptureKitCaptureService` в `live()`; `RecognizeTextUseCase` — `Sendable`, возвращает `OCRResult` (см. [Phase 7](refactoring-phase-7-ocr-capture-permission.md)).

Точки входа: `llhApp` и SwiftUI preview в `Presentation/Main/ContentView` используют `AppDependencyContainer.live().makeMainViewModel()`.

## MainViewModel (состояние после Phase 3 / Phase 4)

- Единственный designated init: `init(dependencies: AppDependencyContainer)`.
- Repositories и `OpenAIServing` не инжектируются напрямую — только use cases и overlay service.
- `TranslationOverlayService` остаётся конкретным типом в контейнере; lifecycle overlay после format — `TranslationOverlayCoordinator` (Phase 4 inc. 4); v0.2 inc. 7 — user dismiss через `onRequestClose` в coordinator.
- **Phase 4 (завершена):** `let settings`, `history`, `capture`, `study`, `editor`; private `TranslationOverlayCoordinator`; `AppShortcutsCoordinator` в `init`. `FormatCapturedTextUseCase` — в `EditorViewModel`, не в Main.
- **Phase 8 (завершена):** Main ~129 строк, **без `@Published`**; `statusMessage` на feature ViewModels; UI — `Presentation/Main/` + feature views — см. [Phase 8](refactoring-phase-8-ui-decomposition.md).

## Покрытие тестами (Phase 1)

`llhTests/Phase1RepositoryTests.swift`:

- Roundtrip `JSONHistoryRepository` через временный `history.json`
- Persistence OCR engine через изолированный `UserDefaults` suite
- `KeychainAPIKeyRepository` с in-memory `OpenAITokenStoring`
- Smoke: `MainViewModel` с инжектированными repo/store без user Keychain (`viewModel.history.profiles` после Phase 4)

## Критерии выхода Phase 1

| Критерий | Статус |
|----------|--------|
| `MainViewModel` не конструирует concrete services | выполнено |
| OpenAI через `OpenAIServing` | выполнено |
| History/settings/keychain через protocols | выполнено |
| Тестируемость с fakes | выполнено |
| Без изменения storage/OCR/OpenAI behavior | выполнено |

## See Also

- [Refactoring Phase 10 Cleanup](refactoring-phase-10-cleanup.md) — `OpenAIService` и persistence paths после Phase 1
- [Refactoring Phase 9 Testing Strategy](refactoring-phase-9-testing-strategy.md) — `AppDependencyContainer` smoke, repository fakes
- [Refactoring Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md) — split ContentView, per-VM status (завершена)
- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md) — Infrastructure OCR/capture, cancellation (завершена)
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md) — OpenAI modernization (завершена)
- [Refactoring Phase 5 SQLite Persistence](refactoring-phase-5-sqlite-persistence.md) — `SQLiteHistoryRepository`, bootstrap
- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md) — Phase 4 завершена (включая `EditorViewModel`)
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — Phase 3 завершена
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — Domain/Models и Data/OpenAI границы
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь и safety net до DI
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — полный план (архивный snapshot)
