# Refactoring Phase 1 Boundaries And DI

> Sources: llh project, 2026-05-26
> Raw: [Phase 1 boundaries and DI completion](../../raw/refactoring/2026-05-26-phase-1-boundaries-and-di-completion.md)
> Updated: 2026-05-26

## Overview

Phase 1 («Stabilize Boundaries With Protocols And DI») завершена: введены repository- и service-протоколы, адаптеры над существующими реализациями и `AppDependencyContainer` для сборки зависимостей. Поведение приложения для пользователя не менялось. `MainViewModel` больше не создаёт инфраструктуру внутри себя. Phase 2–3 завершены; Phase 4 добавляет feature ViewModels поверх того же контейнера — см. [Phase 4](refactoring-phase-4-presentation.md).

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
| `SettingsRepository` | `UserDefaultsSettingsRepository` | `OpenAISettingsStore` |
| `APIKeyRepository` | `KeychainAPIKeyRepository` | `OpenAITokenStoring` / `KeychainOpenAITokenStore` |

`MainViewModel` после Phase 1 напрямую использовал repositories; после Phase 3 — через use cases (`ManageHistoryUseCase`, `ManageOpenAISettingsUseCase` и др.). Настройки и токен на границе Domain: `SettingsRepository`, `APIKeyRepository` (`loadAPIKey` вместо `loadToken`).

## Протоколы capture/OCR

В `CaptureServiceProtocols.swift`:

- `ScreenRecordingPermissionChecking` ← `ScreenRecordingPermissionService`
- `RegionSelecting` ← `RegionSelectionService` (`AnyObject`, `@MainActor` class)
- `ScreenCapturing` ← `ScreenshotService`
- `OCRServing` ← `OCRService` (локальный OCR; не путать с `OpenAIServing`)

## AppDependencyContainer

- `@MainActor struct` с явным `init(...)` без default-аргументов (из-за MainActor-isolated сервисов).
- `static func live()` — production-граф зависимостей.
- `makeMainViewModel()` — фабрика `MainViewModel`.
- Use cases (Phase 3): `recognizeTextUseCase`, `captureRegionUseCase` (`makeCaptureUseCases`), `formatCapturedTextUseCase`, `manageHistoryUseCase`, `manageProfilesUseCase`, `loadWordStudyUseCase`, `manageOpenAISettingsUseCase`.

Точки входа: `llhApp` и SwiftUI preview в `ContentView` используют `AppDependencyContainer.live().makeMainViewModel()`.

## MainViewModel (состояние после Phase 3)

- Единственный designated init: `init(dependencies: AppDependencyContainer)`.
- Repositories и `OpenAIServing` не инжектируются напрямую — только use cases и overlay service.
- `TranslationOverlayService` пока остаётся конкретным типом в контейнере (протокол overlay — Phase 4+).

## Покрытие тестами (Phase 1)

`llhTests/Phase1RepositoryTests.swift`:

- Roundtrip `JSONHistoryRepository` через временный `history.json`
- Persistence OCR engine через изолированный `UserDefaults` suite
- `KeychainAPIKeyRepository` с in-memory `OpenAITokenStoring`
- Smoke: `MainViewModel` с инжектированными repo/store без user Keychain

## Критерии выхода Phase 1

| Критерий | Статус |
|----------|--------|
| `MainViewModel` не конструирует concrete services | выполнено |
| OpenAI через `OpenAIServing` | выполнено |
| History/settings/keychain через protocols | выполнено |
| Тестируемость с fakes | выполнено |
| Без изменения storage/OCR/OpenAI behavior | выполнено |

## See Also

- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md) — presentation split
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — Phase 3 завершена
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — Domain/Models и Data/OpenAI границы
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь и safety net до DI
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — полный план (архивный snapshot)
