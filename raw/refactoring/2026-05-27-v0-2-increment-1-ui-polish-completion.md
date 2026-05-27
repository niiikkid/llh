# v0.2 Increment 1 — Quick UI Polish (completion)

> Source: llh repository implementation (Cursor session)
> Collected: 2026-05-27
> Published: Unknown

Завершён **Increment 1** плана v0.2: быстрая UI-полировка и русификация без изменения data flow и persistence.

## Toolbar (`MainChromeView`)

- Убрана видимая подпись «Движок OCR»; `Picker` с `.labelsHidden()`, ширина 200 pt, `.help` и `accessibilityLabel("Движок OCR")`.
- Кнопки «Скрыть/Показать сессии» и «Настройки» — только SF Symbol, подсказки через `.help`.

## Сессии (`HistoryView`)

- В списке переводов выбранной сессии убраны даты (`formattedDate` больше не показывается в списке).
- Язык сессии: `SessionLanguageBadge` — globe для авто, emoji-флаги 🇬🇧/🇪🇸/🇨🇳 для конкретных языков + `LearningLanguage.title`.
- Picker сессий и алерт удаления используют `LearningProfile.displayName`.

## Русификация

- Общее имя приложения: **«Помощник по изучению языков»** — `AppDisplayStrings.productName` в `Presentation/Shared/AppDisplayStrings.swift`; используется в `MainChromeView`, `MenuBarPanelView`, `MenuBarExtra` (`llhApp`).
- Menu bar panel: **«Захват»**, **«Открыть окно»** (логика окна без изменений — дубли окон исправляются в Increment 10).
- `CapturePermissionBannerView`: русский текст пути в системные настройки; кнопка **«Системные настройки»**.
- Сессия по умолчанию в UI: **«По умолчанию»** через `displayName`; в storage по-прежнему `"Default"` (без миграции).

## Domain (только display helpers)

- `LearningLanguage.flagEmoji` — emoji для UI; `auto` → nil (globe в view).
- `LearningProfile.displayName` — маппинг `isDefaultProfile` или `name == "Default"` → «По умолчанию».
- `HistoryViewModel.selectedProfileDisplayName` для user-visible строк.

## Не входило в инкремент

- Increment 10 (single main window) не реализован.
- Вкладка настроек «OpenAI» оставлена как бренд.
- Increment 2–9 без изменений.

## Затронутые файлы

- `llh/Presentation/Shared/AppDisplayStrings.swift` (новый)
- `llh/Presentation/Main/MainChromeView.swift`
- `llh/Presentation/History/HistoryView.swift`
- `llh/Presentation/History/HistoryViewModel.swift`
- `llh/Presentation/Capture/CapturePermissionBannerView.swift`
- `llh/MenuBarPanelView.swift`
- `llh/llhApp.swift`
- `llh/Domain/Models/LearningLanguage.swift`
- `llh/Domain/Models/LearningProfile.swift`
