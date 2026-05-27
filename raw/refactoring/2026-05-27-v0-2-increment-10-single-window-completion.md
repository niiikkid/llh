# v0.2 Increment 10 — Single Main Window (completion)

> Source: llh repository implementation (Cursor session)
> Collected: 2026-05-27
> Published: Unknown

Завершён **Increment 10** плана v0.2: «Открыть окно» в menu bar активирует существующее главное окно вместо создания дубликатов.

## Поведение

- Если главное окно уже есть (в т.ч. свёрнуто в Dock) — `makeKeyAndOrderFront` / `deminiaturize`, без `openWindow`.
- Если окна нет (пользователь закрыл или ещё не открывал) — один вызов `openWindow(id: "main-window")`.
- `NSApp.activate(ignoringOtherApps: true)` сохранён.

## Реализация

- `App/MainWindowActivator.swift` — поиск окна по `accessibilityIdentifier == "llh.main-window"`.
- `MainWindowIdentityView` (`NSViewRepresentable`) в `ContentView` — проставляет идентификатор при `viewDidMoveToWindow`.
- `MenuBarPanelView` — `activateExisting()` перед `openWindow`.

## Затронутые файлы

- `llh/App/MainWindowActivator.swift` (новый)
- `llh/Presentation/Main/ContentView.swift`
- `llh/MenuBarPanelView.swift`
