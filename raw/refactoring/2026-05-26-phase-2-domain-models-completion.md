# Phase 2 Domain Models Extraction (llh)

> Source: llh repository — Phase 2 implementation (Domain/Models extraction from MainViewModel)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

Phase 2 of the refactoring roadmap ("Extract Domain Models And Errors") — **first deliverable completed**: all product domain types previously defined at the top of `MainViewModel.swift` were moved into `llh/Domain/Models/` without behavior changes. `MainViewModel` now contains only presentation coordination (`@MainActor` class, `CaptureTriggerSource`, workflow methods).

Remaining Phase 2 items per roadmap (not done in this change):

- Move user-facing workflow errors into `Domain/Errors`
- Move `HistoryStoreSnapshot` / legacy persistence DTOs from `HistoryPersistenceService` into Data-layer mappers
- Extract `openAIInstructionName` / `formattingRules` from `LearningLanguage` into `Data/OpenAI` prompt builder

No user-facing behavior changes. App and test targets build successfully.

## MainViewModel size

- Before: ~1316 lines (domain models + ViewModel)
- After: 744 lines (ViewModel only)

## New files — `llh/Domain/Models/`

| File | Types |
|------|-------|
| `FormattingStatus.swift` | `FormattingStatus` |
| `LearningLanguage.swift` | `LearningLanguage` (still includes OpenAI prompt strings — to extract later) |
| `OCREngine.swift` | `OCREngine` |
| `StructuredFormattedText.swift` | `StructuredFormattedText` |
| `StudyMaterials.swift` | `StudyListItem`, `CharacterMeaning`, `WordStudyEntry`, `WordStudyPayload`, `PhraseStudyPayload`, `GrammarExample`, `GrammarStructure`, `GrammarExplanationPayload`, `StudyAssistantData`, `LegacyGrammarExplanation`, `StudyMaterials` |
| `CapturedTextEntry.swift` | `CapturedTextEntry` (includes legacy `Codable` migration from `studyAssistantData`; uses `NSImage?` for in-memory capture preview) |
| `LearningProfile.swift` | `LearningProfileKind`, `LearningProfile` |
| `SessionReadingSequenceItem.swift` | `SessionReadingSequenceItem` |
| `TranslationOverlayTiming.swift` | `LatestTranslationLookup`, `TranslationOverlayTiming` |

## Intentionally unchanged locations

- `HistoryStoreSnapshot` — still in `HistoryPersistenceService.swift`
- `OpenAIModel`, `OpenAIServiceError`, `OpenAITokenStoreError` — still in `OpenAIService.swift` and related Data/Infrastructure
- `MainViewModel` — still owns all user workflows (use cases not extracted yet; Phase 3)

## Tests added

- `llhTests/Phase2DomainModelsTests.swift`
  - `LearningProfile.defaultProfile()` invariants
  - `StructuredFormattedText.sessionListSourceDisplay` for Chinese + pinyin
  - `TranslationOverlayTiming.duration` minimum clamp

Existing tests (`RefactorBaselineTests`, `Phase1RepositoryTests`, `llhTests.swift`) unchanged; they import types from the same `llh` module.

## Exit criteria (Phase 2 roadmap — partial)

| Criterion | Status |
|-----------|--------|
| Domain models removed from `MainViewModel.swift` | done |
| Legacy history `Codable` on `CapturedTextEntry` preserved | done |
| No product behavior change | done |
| Prompt strings removed from `LearningLanguage` | pending |
| `Domain/Errors` introduced | pending |
| Persistence snapshots in Data only | pending |

## Next step (roadmap)

Complete remaining Phase 2 sub-steps, then **Phase 3**: extract use cases (`CaptureRegionUseCase`, `RecognizeTextUseCase`, `FormatCapturedTextUseCase`, `ManageHistoryUseCase`, etc.) workflow by workflow.
