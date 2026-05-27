# v0.2 Increment 4 — Translation Result State (completion)

> Source: llh repository implementation (Cursor session)
> Collected: 2026-05-27
> Published: Unknown

Завершён **Increment 4** плана v0.2: единое отображение результата перевода без вкладок «Сырой текст» / «Форматированный».

## Поведение

- Удалён segmented picker и тип `TranslationTextTab`; состояние выводится из `FormattingStatus` через `TranslationResultPresentationResolver`.
- **Загрузка:** сырой OCR-текст в `TextEditor` (read-only) + баннер с `ProgressView` «Форматирую текст…».
- **Успех:** прокручиваемый форматированный блок + `StudyAssistantView` (как раньше во вкладке «Форматированный»).
- **Ошибка:** оранжевый баннер с сообщением (`statusMessage` или дефолт на русском) + редактируемый сырой текст; retry — только иконка `arrow.clockwise` в нижней панели.
- **Без форматирования:** редактируемый сырой текст (`notRequested` и прочие случаи).

## Затронутые файлы

- `llh/Presentation/Editor/TranslationResultPresentation.swift` — enum + resolver
- `llh/Presentation/Editor/TranslationEditorView.swift` — единый layout
- `llh/Presentation/Editor/FormattedTranslationContentView.swift` — только успешный формат + study
- `llh/Presentation/Editor/EditorViewModel.swift` — `translationResultPresentation`, `formattingFailureMessage`
- `llh/Presentation/Main/ContentView.swift`, `MainWorkspaceView.swift`, `TranslationDetailPanelView.swift` — убран binding вкладок
- `llhTests/TranslationResultPresentationResolverTests.swift`
