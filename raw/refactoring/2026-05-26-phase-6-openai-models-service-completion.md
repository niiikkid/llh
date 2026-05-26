# Phase 6 OpenAI Models Service (llh)

> Source: llh repository — Phase 6 PR 3 implementation
> Collected: 2026-05-26
> Published: Unknown

## Summary

Phase 6 PR 3: extracted `OpenAIModelsService` (`GET /v1/models`, decode, sort, `noModelsFound`). `OpenAIService.fetchModels` delegates. Models list DTOs removed from `OpenAIService.swift`. `OpenAIServing` and use cases unchanged. Settings/Keychain remain in `OpenAIService.swift`.

## Files

- `llh/Data/OpenAI/OpenAIModelsService.swift` (new)
- `llh/Services/OpenAIService.swift` (delegate + shared `httpClient`/`modelsService` wiring)
- `llhTests/Phase6OpenAIModelsServiceTests.swift` (new)
- `llhTests/OpenAIHTTPClientTestSupport.swift` (shared URLProtocol stub)

## API (unchanged)

- `GET https://api.openai.com/v1/models`
- Bearer auth via `OpenAIHTTPClient`
- Response: `{ "object": "list", "data": [{ "id": "..." }, ...] }`

## Next

Phase 6 PR 4: `OpenAIOCRService` behind OCR boundary.
