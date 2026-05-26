# Phase 6 OpenAI OCR Service (llh)

> Source: llh repository — Phase 6 PR 4 implementation
> Collected: 2026-05-26
> Published: Unknown

## Summary

Phase 6 PR 4: extracted `OpenAIOCRService` (vision `POST /v1/chat/completions`, JPEG base64 `data:image/jpeg;base64,...`). Domain protocol `OpenAIOCRServing`. `RecognizeTextUseCase` routes local `OCRServing` vs `OpenAIOCRServing` (no longer depends on full `OpenAIServing` for AI OCR). `OpenAIService.recognizeTextInImage` delegates. `AppDependencyContainer.live()` shares one `OpenAIHTTPClient` across OCR + facade.

## Files

- `llh/Domain/Services/OpenAIOCRServing.swift` (new)
- `llh/Data/OpenAI/OpenAIOCRService.swift` (new)
- `llh/Services/OpenAIService.swift` (delegate; vision DTOs removed)
- `llh/Domain/UseCases/RecognizeTextUseCase.swift` (`openAIOCRService`)
- `llh/App/AppDependencyContainer.swift` (shared httpClient wiring)
- `llhTests/Phase6OpenAIOCRServiceTests.swift` (new, 4 tests)
- `llhTests/Phase3CaptureRegionUseCaseTests.swift`, `Phase1RepositoryTests.swift` (DI)

## API (unchanged)

- `POST https://api.openai.com/v1/chat/completions`
- User message: `text` + `image_url` with `data:image/jpeg;base64,...` (OpenAI Vision guide)
- Bearer auth via `OpenAIHTTPClient`

## Next

Phase 6 PR 5: optional Responses API / endpoint modernization after Context7 review; or split format/study services.
