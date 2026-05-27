# v0.2 Increment 8 — Session Reading Overview Details (completion)

> Source: llh repository implementation (Cursor session)
> Collected: 2026-05-27
> Published: Unknown

Завершён **Increment 8** плана v0.2: режим «Весь текст сессии» показывает сохранённые учебные детали по записи.

## Поведение

- У каждой записи с уже загруженными словами и/или грамматикой (`wordsStatus` / `grammarStatus` == `.succeeded` и непустой payload) — кнопка «глаз».
- Раскрытие показывает компактный блок: «Перевод слов» и/или «Грамматика» из `StudyMaterials` записи.
- Нет фоновой подгрузки OpenAI из overview; только данные, уже лежащие в истории.
- Копирование всего текста сессии не менялось — только source + translation lines.
- При выходе из режима «вся сессия» сбрасывается набор раскрытых записей.

## Затронутые файлы

- `llh/Domain/Models/SessionReadingSequenceItem.swift` — `wordStudy`, `grammarStudy`, `hasExpandableDetails`, `init(entry:learningLanguage:)`
- `llh/Presentation/History/HistoryViewModel.swift` — mapping через новый initializer
- `llh/Presentation/History/SessionReadingOverviewView.swift` — eye toggle, compact details views
- `llhTests/llhTests.swift` — тесты доступности study payloads
