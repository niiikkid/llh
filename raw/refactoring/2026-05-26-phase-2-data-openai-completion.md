# Phase 2 Data/OpenAI Boundaries (llh)

> Source: llh repository — Phase 2 second increment (Data persistence snapshot, OpenAI types, centralized prompts)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

Phase 2 of the refactoring roadmap ("Extract Domain Models And Errors") — **second increment completed**: persistence JSON snapshot, OpenAI infrastructure types, and all OpenAI prompt strings moved out of `LearningLanguage` and `OpenAIService` into the Data layer. `OpenAIServing` protocol moved to Domain. No user-facing behavior changes. App target builds successfully.

Optional roadmap item still open: `Domain/Errors` for user-facing **workflow** errors (distinct from `OpenAIServiceError`, which is an API/infrastructure error in Data).

## New / moved files

### `llh/Data/Persistence/`

| File | Types |
|------|-------|
| `HistoryStoreSnapshot.swift` | `HistoryStoreSnapshot` — JSON on-disk shape for `history.json`, not a domain entity |

`HistoryPersistenceService.swift` keeps load/save logic and private `StoredHistoryRecord` for legacy array migration.

### `llh/Data/OpenAI/`

| File | Types / role |
|------|----------------|
| `OpenAIModel.swift` | `OpenAIModel` |
| `OpenAIServiceError.swift` | `OpenAIServiceError` (`LocalizedError`, Russian user messages) |
| `OpenAIPromptBuilder.swift` | Centralized prompts: instruction names, formatting rules, format/OCR/study prompts, pinyin tone helpers (~266 lines) |

### `llh/Domain/Services/`

| File | Types |
|------|-------|
| `OpenAIServing.swift` | `OpenAIServing` protocol (moved from `OpenAIService.swift`) |

## `LearningLanguage` after cleanup

Product-only API remains:

- `title` (UI)
- `supportsWordStudy`

Removed: `openAIInstructionName`, `formattingRules` (now `OpenAIPromptBuilder.openAIInstructionName(for:)` and `OpenAIPromptBuilder.formattingRules(for:)`).

## `OpenAIService` after cleanup

- ~737 lines (HTTP, DTOs, request/response mapping, settings store helpers)
- Calls `OpenAIPromptBuilder` for all prompt construction
- No longer defines `OpenAIModel`, `OpenAIServiceError`, `OpenAIServing`, or static `wordsAnalysisPrompt`

## `RefactorBaselineInventory` prompt map

| Call site | Builder |
|-----------|---------|
| `formatRecognizedText` | `OpenAIPromptBuilder.formatRecognizedTextSystemPrompt` / `formatRecognizedTextUserPrompt` |
| `recognizeTextInImage` | `OpenAIPromptBuilder.recognizeTextInImageUserPrompt` |
| `buildWordsStudyData` | `OpenAIPromptBuilder.wordsAnalysisPrompt(for:)` |
| `buildPhrasesStudyData` | `OpenAIPromptBuilder.phrasesStudySystem/UserPrompt` |
| `buildGrammarStudyData` | `OpenAIPromptBuilder.grammarStudySystem/UserPrompt` |
| `fetchModels` | no prompt (GET /v1/models) |

## Tests updated / added

- `RefactorBaselineTests`: `openAIPromptBuilder_formattingRules_areNonEmptyForAllCases`, `openAIPromptBuilder_wordsAnalysisPrompt_chineseIncludesToneRules`; inventory expects `OpenAIPromptBuilder` paths
- `llhTests.swift`: word-study prompt tests use `OpenAIPromptBuilder.wordsAnalysisPrompt`
- `Phase2DomainModelsTests.swift`: `openAIPromptBuilder_formatRecognizedTextUserPrompt_includesRawText`, `historyStoreSnapshot_roundtripsThroughJSON`

## Exit criteria (Phase 2 roadmap)

| Criterion | Status |
|-----------|--------|
| Domain models removed from `MainViewModel.swift` | done (increment 1) |
| Legacy history `Codable` on `CapturedTextEntry` preserved | done |
| No product behavior change | done |
| Prompt strings removed from `LearningLanguage` | done |
| Persistence snapshots in Data only | done |
| `OpenAIModel` / `OpenAIServiceError` in Data/OpenAI | done |
| `OpenAIServing` at Domain boundary | done |
| `Domain/Errors` for workflow errors | pending (optional) |

## Next step (roadmap)

**Phase 3**: extract use cases workflow by workflow, starting with `CaptureRegionUseCase`.
