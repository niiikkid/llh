# v0.2 Increment 9 — Dock Language Badge (completion)

> Source: llh repository implementation (Cursor session)
> Collected: 2026-05-27
> Published: Unknown

Завершён **Increment 9** плана v0.2: badge на иконке приложения в Dock показывает язык активной сессии.

## Поведение

- Конкретный язык сессии — flag emoji в `NSApp.dockTile.badgeLabel` (🇬🇧 / 🇪🇸 / 🇨🇳).
- `Автоопределение` — badge сбрасывается (`nil`).
- Нет выбранной сессии — badge сбрасывается.
- Обновление при смене `selectedProfileID` / `profiles` и после `loadFromDisk()` на старте.

## Реализация

- `LearningLanguage.dockBadgeLabel` — делегирует `flagEmoji` (`auto` → `nil`).
- `App/DockLanguageBadgeController.swift` — `update(for:)` выставляет `badgeLabel` и вызывает `display()`.
- `MainViewModel` — Combine-подписка `history.$selectedProfileID` + `history.$profiles` → `activeProfile?.learningLanguage`.

## Тесты

- `learningLanguage_dockBadgeLabel_usesFlagOrClearsForAuto` в `llhTests.swift`.
- Смена badge при переключении сессий — manual UI verification.

## Затронутые файлы

- `llh/App/DockLanguageBadgeController.swift` (новый)
- `llh/Domain/Models/LearningLanguage.swift`
- `llh/MainViewModel.swift`
- `llhTests/llhTests.swift`
