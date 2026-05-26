# Phase 10 Cleanup Completion

> Source: llh project implementation
> Collected: 2026-05-27
> Published: 2026-05-27

Phase 10 completed cleanup and product decisions after Phases 0–9.

## Product decisions

| Topic | Decision |
|-------|----------|
| Phrase study generation (`buildPhrasesStudyData`) | **Removed** from `OpenAIServing` / prompts; deferred until a dedicated use case + UI exist |
| Grammar study generation (`buildGrammarStudyData`) | **Removed**; same rationale |
| Word-click translation | **Deferred** — tracked in `TODO.txt` |
| Session vocabulary aggregation | **Deferred** — `TODO.txt` |
| OpenAI cost / token usage stats | **Deferred** — `TODO.txt` |
| Speech / pronunciation | **Deferred** — `TODO.txt` |
| Repeated capture hotkey | **Kept**: `CaptureViewModel.triggerCaptureFromHotkey()` cancels while `isProcessing` (selection/OCR); does not cancel post-capture formatting |
| JSON history backup | **Kept** — `JSONHistoryRepository` + `HistoryPersistenceService` remain for migration fallback |

Legacy `StudyMaterials.phrases` / `grammar` fields and decode/repair paths remain for old saved data.

## Code cleanup

- Removed unwired phrase/grammar OpenAI API and `OpenAIPromptBuilder` prompts/DTOs.
- Added `StructuredFormattedText.overlayPrimaryText`; removed duplicate logic from `TranslationOverlayService` and `TranslationOverlayTiming`.
- Relocated `llh/Services/` types: `OpenAIService` → `Data/OpenAI/`, `HistoryPersistenceService` → `Data/Persistence/`, capture helpers → `Infrastructure/Capture/`.
- Deleted empty `llh/Services/` directory.
- Updated `RefactorBaselineInventory` (`OpenAICallSite` count 4).
- Tests: `Phase10CaptureViewModelTests` (hotkey cancel), `Phase9OpenAIPromptTests` overlay primary text; removed phrase/grammar prompt tests.

## Exit criteria (roadmap)

- No unused OpenAI study paths without product intent — satisfied (only `buildWordsStudyData` remains).
- No obsolete persistence path removed without approval — JSON backup kept.
- Large old files — `Services/` eliminated; overlay dedup reduces `TranslationOverlayService` size.
