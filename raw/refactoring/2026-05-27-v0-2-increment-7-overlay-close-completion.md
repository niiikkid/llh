# v0.2 Increment 7 — Compact Overlay Closing (completion)

> Source: llh repository implementation (Cursor session)
> Collected: 2026-05-27
> Published: Unknown

Завершён **Increment 7** плана v0.2: компактное окно перевода можно закрыть предсказуемо.

## Поведение

- Кнопка ✕ в правом верхнем углу overlay; tooltip «Закрыть (Escape)».
- Escape закрывает видимый overlay через глобальный `NSEvent` monitor (keyCode 53), независимо от настройки горячей клавиши в Settings.
- `panel.ignoresMouseEvents = false` — кнопка кликабельна на borderless panel.
- Закрытие пользователем → `TranslationOverlayService.onRequestClose` → `TranslationOverlayCoordinator.close()` (сброс awaiting + `hide()`).
- Loading и persistent last translation: без auto-dismiss (`dismissAfter: nil`); таймер только для временного перевода/сообщений.
- `TranslationOverlayDismissSchedule.shouldScheduleAutomaticDismiss` — unit-тест в `llhTests`.

## Затронутые файлы

- `llh/TranslationOverlayService.swift`
- `llh/Presentation/Overlay/TranslationOverlayCoordinator.swift`
- `llh/Presentation/Settings/SettingsView.swift` (пояснение в настройках)
- `llhTests/llhTests.swift`
