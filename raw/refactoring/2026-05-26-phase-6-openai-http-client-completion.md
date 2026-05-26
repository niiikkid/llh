# Phase 6 OpenAI HTTP Client (llh)

> Source: llh repository — Phase 6 first increment (OpenAIHTTPClient extraction)
> Collected: 2026-05-26
> Published: 2026-05-26

## Status

Phase 6 of the refactoring roadmap («OpenAI Integration Modernization») — **PR 2 completed** (PR 1 prompt builder was done in Phase 2): low-level HTTP transport extracted from `OpenAIService` into `OpenAIHTTPClient`. No endpoint changes; still Chat Completions API (`/v1/chat/completions`) and Models API (`/v1/models`). No user-facing behavior changes.

## New file

### `llh/Data/OpenAI/OpenAIHTTPClient.swift`

| Responsibility | Detail |
|----------------|--------|
| Base URL | `https://api.openai.com/v1` |
| Auth | `Authorization: Bearer {token}`, `Content-Type: application/json` |
| Methods | `get(path:apiKey:)`, `post(path:apiKey:body:)`, `decode(_:as:)`, `trimmedToken(from:)` |
| Status mapping | `401` → `unauthorized`, `429` → `rateLimited`, other non-2xx → `unexpectedStatusCode` |
| Network mapping | `cannotFindHost`/`dnsLookupFailed` → `hostNotFound`; offline codes → `networkUnavailable` |

## `OpenAIServiceError` change

New case: `rateLimited` — Russian user message for OpenAI rate limit (HTTP 429).

## `OpenAIService` after refactor

- Injects `OpenAIHTTPClient` (init with `URLSession` or injectable `httpClient`)
- ~602 lines (was ~737): DTOs, mapping, settings/keychain helpers remain in `Services/OpenAIService.swift`
- All HTTP calls delegate to client:
  - `fetchModels` → `GET /models`
  - `recognizeTextInImage`, `formatRecognizedText`, study methods → `POST /chat/completions`
- `OpenAIServing` protocol unchanged — use cases and ViewModels unaffected

## Tests

`llhTests/Phase6OpenAIHTTPClientTests.swift` (8 tests via `URLProtocol` stub):

- Token validation (empty, invalid prefix, trim)
- GET `/models` — Bearer header, decode
- POST — 401, 429, 500 status mapping
- URLError — host not found, network unavailable

`RefactorBaselineTests`: `rateLimited` added to error description samples; 429 now maps to dedicated case (not `unexpectedStatusCode(429)`).

## Roadmap PR status (Phase 6)

| PR | Task | Status |
|----|------|--------|
| 1 | Prompt builder extraction | done (Phase 2) |
| 2 | HTTP client extraction | **done** |
| 3 | Model/settings separation (`OpenAIModelsService`) | pending |
| 4 | AI OCR service extraction | pending |
| 5 | Optional Responses API / structured outputs | pending (after Context7 docs review) |

## Next step

**Phase 6 PR 3**: extract `OpenAIModelsService` from `OpenAIService`; keep `OpenAIServing` facade or split domain protocols incrementally.
