# v0.2 Increment 5 — Words And Grammar Tabs (completion)

> Source: llh repository implementation (Cursor session)
> Collected: 2026-05-27
> Published: Unknown

Завершён **Increment 5** плана v0.2: вкладки «Перевод слов» и «Грамматика» в главном окне с отдельными запросами.

## Поведение

- `StudyAssistantView`: segmented control `Перевод слов` / `Грамматика`; кнопка загрузки/обновления и loading/retry только для активной вкладки.
- Слова: прежний `WordStudyPayload` / `WordStudyEntriesView`, статус `wordsStatus`.
- Грамматика: отдельный OpenAI path `buildGrammarStudyData` → `LoadGrammarStudyUseCase` → `grammar` / `grammarStatus` в `StudyMaterials`.
- Промпты: `OpenAIPromptBuilder.grammarStudySystemPrompt` / `grammarStudyUserPrompt` — краткое объяснение на русском, как части предложения связаны и откуда смысл.

## Затронутые файлы

- `llh/Domain/UseCases/LoadGrammarStudyUseCase.swift`
- `llh/Domain/Services/OpenAIServing.swift` — `buildGrammarStudyData`
- `llh/Data/OpenAI/OpenAIStudyService.swift`, `OpenAIService.swift`, `OpenAIPromptBuilder.swift`
- `llh/Presentation/Study/StudyLearningTab.swift`, `GrammarExplanationView.swift`
- `llh/Presentation/Study/StudyViewModel.swift`, `StudyAssistantView.swift`
- `llh/App/AppDependencyContainer.swift`, `MainViewModel.swift`
- `llhTests/Phase3LoadGrammarStudyUseCaseTests.swift`; обновлены fakes `OpenAIServing`; prompt test в `llhTests.swift`
- `RefactorBaselineInventory` — `OpenAICallSite` count **5**
