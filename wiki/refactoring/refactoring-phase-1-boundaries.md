# Refactoring Phase 1 Boundaries And DI

> Sources: llh project, 2026-05-26
> Raw: [Phase 1 boundaries and DI completion](../../raw/refactoring/2026-05-26-phase-1-boundaries-and-di-completion.md)
> Updated: 2026-05-26

## Overview

Phase 1 («Stabilize Boundaries With Protocols And DI») завершена: введены repository- и service-протоколы, адаптеры над существующими реализациями и `AppDependencyContainer` для сборки зависимостей. Поведение приложения для пользователя не менялось. `MainViewModel` больше не создаёт инфраструктуру внутри себя. Phase 2 завершена; Phase 3 добавляет use cases в контейнер — см. [Phase 2](refactoring-phase-2-domain-models.md), [Phase 3](refactoring-phase-3-use-cases.md).

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

`MainViewModel` вызывает `historyRepository.loadStore()` / `saveStore(_:)` вместо прямого `HistoryPersistenceService`. Настройки и токен — через `settingsRepository` и `apiKeyRepository` (`loadAPIKey` вместо `loadToken` на границе Domain).

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

Точки входа: `llhApp` и SwiftUI preview в `ContentView` используют `AppDependencyContainer.live().makeMainViewModel()`.

## MainViewModel

- Единственный designated init: `init(dependencies: AppDependencyContainer)`.
- `settingsRepository` объявлен как `var` — мутация свойств через protocol existential (`{ get set }`).
- `TranslationOverlayService` пока остаётся конкретным типом в контейнере (протокол overlay — позже).

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

- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — use cases поверх протоколов Phase 1
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — Domain/Models и Data/OpenAI границы
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь и safety net до DI
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — полный план (архивный snapshot)
