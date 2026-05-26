# Phase 6 Translation and Study Services (llh)

> Source: llh repository — Phase 6 PR 5 implementation
> Collected: 2026-05-26
> Published: Unknown

## Summary

Phase 6 PR 5: extracted `OpenAITranslationService` (format recognized text) and `OpenAIStudyService` (words/phrases/grammar study). Shared `OpenAIChatCompletionClient` for text Chat Completions + JSON extraction. `OpenAIService` delegates format/study; endpoint unchanged (`POST /v1/chat/completions`). Context7 review: keep Chat Completions for this PR; Responses API migration deferred.

## Files

- `llh/Data/OpenAI/OpenAIChatCompletionClient.swift` (new)
- `llh/Data/OpenAI/OpenAITranslationService.swift` (new)
- `llh/Data/OpenAI/OpenAIStudyService.swift` (new)
- `llh/Services/OpenAIService.swift` (delegate; format/study DTOs removed)
- `llhTests/Phase6OpenAITranslationServiceTests.swift` (new, 4 tests)
- `llhTests/Phase6OpenAIStudyServiceTests.swift` (new, 3 tests)

## API (unchanged)

- `POST https://api.openai.com/v1/chat/completions`
- `messages` with `system` + `user` roles
- Response: `choices[0].message.content` (JSON in content for format/study)

## Next

Phase 6 PR 6 (optional): extract settings/keychain from `OpenAIService.swift`; HTTP timeout/cancellation; or Responses API after separate Context7 plan.
