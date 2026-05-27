# v0.2 Increment 2 — Session Navigation (completion)

> Source: llh repository implementation (Cursor session)
> Collected: 2026-05-27
> Published: Unknown

Завершён **Increment 2** плана v0.2: отдельная страница управления сессиями, маршрутизация главного окна, переименование на уровне use case.

## Поведение

- Страница **Сессии**: список всех сессий, создать / открыть / переименовать / удалить.
- Язык сессии только при создании; в списке и workspace отображается read-only badge.
- Workspace: боковая панель **Переводы** (без picker сессий) — список записей активной сессии.
- Навигация `AppMainRoute`: `sessions`, `workspace`, `settings` (настройки встроены в окно, не sheet).
- Кнопка toolbar «Все сессии» / «К переводам»; настройки с возвратом на предыдущий маршрут.

## Domain

- `ManageProfilesUseCase.renameProfile`, `deleteProfile(profileID:)`, `canDeleteProfile(profileID:)`.
- `ManageProfilesRenameOutcome`, расширен `ManageProfilesDeleteOutcome.profileNotFound`.

## Presentation

- `SessionsListView`, `AppMainRoute`, `SessionLanguageBadge` (shared).
- `HistoryView` — только список переводов выбранной сессии.
- `ContentView` / `MainChromeView` / `MainWorkspaceView` — маршруты и переименование sidebar.

## Тесты

- `Phase3ManageProfilesUseCaseTests`: rename, delete non-selected, profileNotFound.

## Затронутые файлы

- `llh/Domain/UseCases/ManageProfilesUseCase.swift`
- `llh/Presentation/History/HistoryViewModel.swift`
- `llh/Presentation/History/HistoryView.swift`
- `llh/Presentation/History/SessionsListView.swift` (новый)
- `llh/Presentation/Shared/SessionLanguageBadge.swift` (новый)
- `llh/Presentation/Main/AppMainRoute.swift` (новый)
- `llh/Presentation/Main/ContentView.swift`
- `llh/Presentation/Main/MainChromeView.swift`
- `llh/Presentation/Main/MainWorkspaceView.swift`
- `llhTests/Phase3ManageProfilesUseCaseTests.swift`
