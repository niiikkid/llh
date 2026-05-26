# Phase 6 Settings/Keychain Extraction and HTTP Timeout (llh)

> Source: llh repository — Phase 6 PR 6 implementation
> Collected: 2026-05-26
> Published: Unknown

## Summary

Phase 6 PR 6 (final): extracted `OpenAITokenStore` / `KeychainOpenAITokenStore` and `OpenAISettingsStore` from `OpenAIService.swift` into `Data/OpenAI/`. `OpenAIService` is now a pure `OpenAIServing` facade. Added `requestTimeout` (default 120s), `OpenAIServiceError.timeout` / `.cancelled`, and task cancellation propagation in `OpenAIHTTPClient`.

Context7 (2026-05-26): Chat Completions remains supported; Responses API recommended for new projects but deferred — vision/multimodal migration is a separate effort.

## Files

- `llh/Data/OpenAI/OpenAITokenStore.swift` (new)
- `llh/Data/OpenAI/OpenAISettingsStore.swift` (new)
- `llh/Services/OpenAIService.swift` (facade only)
- `llh/Data/OpenAI/OpenAIHTTPClient.swift` (timeout + cancellation)
- `llh/Data/OpenAI/OpenAIServiceError.swift` (+ timeout, cancelled)
- `llhTests/Phase6OpenAIHTTPClientTests.swift` (+4 tests)
- `llhTests/RefactorBaselineTests.swift` (error samples)

## HTTP client behavior

- `request.timeoutInterval` = `requestTimeout` (default 120s)
- `Task.checkCancellation()` before network call
- `CancellationError` propagates unchanged
- `URLError.timedOut` → `.timeout`
- `URLError.cancelled` → `.cancelled`

## Phase 6 exit

All Phase 6 roadmap criteria complete except Responses API migration (explicitly deferred per incremental migration guidance).
