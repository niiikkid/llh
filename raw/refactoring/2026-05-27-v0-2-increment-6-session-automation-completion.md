# v0.2 Increment 6 — Session-Level Automation (completion)

> Source: llh repository implementation (Cursor session)
> Collected: 2026-05-27
> Published: Unknown

Завершён **Increment 6** плана v0.2: per-session автозагрузка слов и грамматики после успешного форматирования.

## Поведение

- `LearningProfile`: `automaticallyLoadWords`, `automaticallyLoadGrammar` (Codable default `false` для legacy JSON/SQLite).
- SQLite migration `v2_profile_session_automation`: колонки `auto_load_words`, `auto_load_grammar`.
- `SessionsListView`: toggles при создании сессии; sheet «Автозагрузка» (gearshape) на списке сессий.
- `EditorViewModel.applyFormattingSuccess` → `StudyViewModel.startSessionAutomationAfterFormattingSuccess` — отдельные `Task` для слов и грамматики; не вызывается при ошибке форматирования.
- Preflight use cases по-прежнему пропускают уже успешные/идущие запросы; manual retry сохранён.

## Затронутые файлы

- `llh/Domain/Models/LearningProfile.swift`
- `llh/Data/Persistence/HistoryDatabaseSchema.swift`, `SQLiteHistoryRepository.swift`
- `llh/Domain/UseCases/ManageProfilesUseCase.swift`
- `llh/Presentation/History/HistoryViewModel.swift`, `SessionsListView.swift`
- `llh/Presentation/Editor/EditorViewModel.swift`
- `llh/Presentation/Study/StudyViewModel.swift`, `StudyAssistantView.swift`
- `llhTests/Phase3ManageProfilesUseCaseTests.swift`, `Phase5HistoryPersistenceTests.swift`, `llhTests.swift`
