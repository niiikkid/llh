# Phase 0 Baseline Completion (llh)

> Source: llh repository — Phase 0 implementation (RefactorBaseline module, RefactorBaselineTests, MainViewModel extract)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

Phase 0 of the refactoring roadmap ("Baseline And Safety Net") was completed. No user-facing behavior changes. One behavior-preserving extract: history load repair logic moved from `MainViewModel.loadHistory` into `HistoryEntryLoadRepair`.

## New code artifacts

- `llh/RefactorBaseline/RefactorBaselineInventory.swift` — machine-readable inventory of `MainViewModel` surface area, persistence triggers, OpenAI call sites, UI consumers.
- `llh/RefactorBaseline/HistoryEntryLoadRepair.swift` — pure functions for repairing persisted entries after interrupted sessions.
- `llhTests/RefactorBaselineTests.swift` — characterization tests and inventory count locks.

## MainViewModel inventory (2026-05-26)

### @Published properties (19)

recognizedText, formattedRecognizedText, studyMaterials, capturedImage, statusMessage, showPermissionHelp, isProcessing, profiles, selectedProfileID, selectedEntryID, availableOpenAIModels, selectedOpenAIModelID, selectedOCREngine, defaultNewProfileLearningLanguage, translationOverlayMinimumDuration, translationOverlaySecondsPerWord, isLoadingOpenAIModels, isFormattingRecognizedText, showsSessionReadingOverview

### Public actions by feature bucket

- **capture:** triggerCapture, refreshPermissionState, openSystemSettings
- **ocr:** selectOCREngine, switchToNextOCREngine
- **translation/formatting:** retryFormattingForSelectedEntry, calculatedTranslationOverlayDuration
- **history:** deleteSelectedEntry, selectEntry, updateSelectedText
- **profiles:** createProfile, selectProfile, deleteSelectedProfile, setDefaultNewProfileLearningLanguage
- **settings:** validateAndSaveOpenAIToken, refreshOpenAIModels, deleteOpenAIToken, selectOpenAIModel, setTranslationOverlayMinimumDuration, setTranslationOverlaySecondsPerWord
- **overlay:** closeTranslationOverlay, toggleLastTranslationOverlay
- **shortcuts:** registered in `MainViewModel.init` via KeyboardShortcuts (not public methods)
- **study:** retryStudyAssistantDataForSelectedEntry (words only)
- **session reading:** copySessionReadingOverviewToPasteboard, toggleSessionReadingOverview, plainTextForSessionReadingCopy, formattedDate

### persistHistory() triggers (11)

userDeleteEntry, userCreateProfile, userDeleteProfile, userEditEntryText, captureInsertedEntry, formatStarted, formatSucceeded, formatFailed, wordStudyStarted, wordStudySucceeded, wordStudyFailed

### OpenAI call sites

| Operation | Wired from MainViewModel | Prompt builder |
|-----------|--------------------------|----------------|
| fetchModels | yes (token validation) | none |
| recognizeTextInImage | yes (AI OCR path) | inline in OpenAIService |
| formatRecognizedText | yes | inline in OpenAIService |
| buildWordsStudyData | yes (loadStudyMaterial) | wordsAnalysisPrompt(for:) |
| buildPhrasesStudyData | **no** | inline in OpenAIService |
| buildGrammarStudyData | **no** | inline in OpenAIService |

### UI consumers of MainViewModel

llhApp (StateObject owner), ContentView, MenuBarPanelView, SettingsTabContainer, OpenAISettingsTab, OverlayTimingSettingsTab

## Characterization tests added (RefactorBaselineTests)

- inventory_mainViewModelPublishedPropertyCount_isStable (19)
- inventory_documentsUnwiredPhraseAndGrammarStudyAPIs
- inventory_openAICallSites_coverAllOpenAIServingMethods
- historyPersistenceService_roundtripsMultipleProfilesWithSelection
- historyPersistenceService_decodesLegacyHistoryOnlyJSONArray
- historyPersistenceService_ensuresDefaultProfileAtIndexZero
- historyEntryLoadRepair_marksInterruptedFormattingAsFailed
- historyEntryLoadRepair_marksInterruptedWordStudyAsFailed
- historyEntryLoadRepair_preservesSucceededFormattingAndClearsEmptyPayload
- historyEntryLoadRepair_normalizesSucceededWhenFormattedTextPresent
- openAISettingsStore_persistsSelectedOCREngineRawValue
- learningLanguage_formattingRules_areNonEmptyForAllCases
- openAIService_wordsAnalysisPrompt_chineseIncludesToneRules
- openAIServiceError_localizedDescriptions_areNonEmptyRussianMessages

## Pre-existing tests still relevant (llhTests.swift)

Includes: history roundtrip (single profile), legacy LearningProfile decode without language, default profile injection on load, overlay timing persistence, wordsAnalysisPrompt variants, capturedTextEntry codable, etc.

## Phase 0 exit criteria checklist

- [x] Inventory represented in code (`RefactorBaselineInventory`) and tests
- [x] Characterization coverage for multi-profile JSON, legacy array JSON, load repair, OCR engine setting, prompts, errors
- [x] No production behavior changes (repair extract only)
- [x] Dead API surface documented: phrase/grammar study not wired to UI

## Next step (roadmap)

Phase 1: `HistoryRepository`, `SettingsRepository`, `APIKeyRepository`, protocol adapters, `AppDependencyContainer`, inject into `MainViewModel`.
