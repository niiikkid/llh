# Refactoring Phase 6 OpenAI Integration

> Sources: llh project, 2026-05-26; OpenAI API documentation (Context7), 2026-05-26
> Raw: [Phase 6 OpenAI HTTP client completion](../../raw/refactoring/2026-05-26-phase-6-openai-http-client-completion.md); [Phase 6 OpenAI models service completion](../../raw/refactoring/2026-05-26-phase-6-openai-models-service-completion.md)
> Updated: 2026-05-26

## Overview

Phase 6 («OpenAI Integration Modernization») **в процессе**. PR 1 (промпты) — Phase 2 (`OpenAIPromptBuilder`). **PR 2** — `OpenAIHTTPClient`. **PR 3** — `OpenAIModelsService` (`GET /v1/models`, validation ключа через listing). `OpenAIService` остаётся фасадом `OpenAIServing`; use cases и UI без изменений. Endpoint **не менялся** — Chat Completions + Models API, Bearer auth.

## Слой Data/OpenAI (текущее)

```text
OpenAIService (Services/) — OpenAIServing facade
  ├── OpenAIHTTPClient      — GET/POST /v1/*, errors, decode helper
  ├── OpenAIModelsService   — GET /models → [OpenAIModel]
  └── … chat DTOs, mapping, OpenAISettingsStore, Keychain (ещё в монолите)
```

| Файл | Назначение |
|------|------------|
| `OpenAIHTTPClient.swift` | Transport (PR 2) |
| `OpenAIModelsService.swift` | Model listing + empty-list guard (PR 3) |
| `OpenAIModel.swift` | Domain-facing model id |
| `OpenAIServiceError.swift` | Typed API errors (вкл. `rateLimited`, `noModelsFound`) |
| `OpenAIPromptBuilder.swift` | Все промпты (Phase 2) |

## Инкремент 2 — OpenAIModelsService (PR 3, завершён)

Вынесены listing и validation моделей из `OpenAIService`:

| Шаг | Поведение |
|-----|-----------|
| HTTP | `GET /models` через общий `OpenAIHTTPClient` |
| Decode | `{ "object": "list", "data": [{ "id": "..." }, ...] }` — лишние поля (`object`, `created`, `owned_by`) игнорируются |
| Map | `data[].id` → `OpenAIModel` |
| Sort | `localizedStandardCompare` по `id` |
| Empty | `OpenAIServiceError.noModelsFound` |

`ManageOpenAISettingsUseCase` по-прежнему вызывает `openAIService.fetchModels` (validation при сохранении/обновлении ключа). `OpenAISettingsStore` / Keychain **не переносились** — отдельный PR позже.

DI: `OpenAIService` создаёт один `OpenAIHTTPClient` и `OpenAIModelsService(httpClient:)` в обоих инициализаторах (`session:` / `httpClient:`).

## Инкремент 1 — OpenAIHTTPClient (PR 2, завершён)

| Файл | Назначение |
|------|------------|
| `Data/OpenAI/OpenAIHTTPClient.swift` | Auth headers, GET/POST, decode, маппинг HTTP/network |
| `Data/OpenAI/OpenAIServiceError.swift` | + `rateLimited` (HTTP 429) |
| `Services/OpenAIService.swift` | DTO, mapping, prompts; делегирует transport/models |

### OpenAIHTTPClient

```text
OpenAIHTTPClient
  ├── trimmedToken(from:)     → sk- prefix validation
  ├── get(path:apiKey:)       → GET /v1/*
  ├── post(path:apiKey:body:) → POST /v1/*
  └── decode(_:as:)           → JSONDecoder wrapper
```

| HTTP | → `OpenAIServiceError` |
|------|-------------------------|
| 401 | `unauthorized` |
| 429 | `rateLimited` |
| other non-2xx | `unexpectedStatusCode` |
| DNS / host | `hostNotFound` |
| offline | `networkUnavailable` |

Base URL: `https://api.openai.com/v1`. Заголовки: `Authorization: Bearer`, `Content-Type: application/json`.

### Методы `OpenAIServing` и HTTP

| Метод | Реализация после PR 3 |
|-------|------------------------|
| `fetchModels` | `OpenAIModelsService` → `GET /models` |
| `recognizeTextInImage` | `OpenAIService` → `POST /chat/completions` (vision) |
| `formatRecognizedText` | `POST /chat/completions` |
| `buildWordsStudyData` / phrases / grammar | `POST /chat/completions` via `performStructuredRequest` |

`AppDependencyContainer.live()` по-прежнему: `OpenAIService()` → use cases.

## Покрытие тестами

| Target | Файл | Сценарии |
|--------|------|----------|
| HTTP client | `Phase6OpenAIHTTPClientTests.swift` (8) | token; GET models + Bearer; 401, 429, 500; URLError |
| Models service | `Phase6OpenAIModelsServiceTests.swift` (3) | сортировка; пустой `data`; 401 |
| Shared stub | `OpenAIHTTPClientTestSupport.swift` | `URLProtocol` для Phase 6 |
| Baseline | `RefactorBaselineTests` | `rateLimited` в error descriptions |
| Use cases | `Phase3*` | без изменений; fakes → `OpenAIServing` |

## Критерии выхода Phase 6 (roadmap)

| Критерий | Статус |
|----------|--------|
| `OpenAIHTTPClient` — transport отдельно | выполнено (PR 2) |
| Prompts centralized (`OpenAIPromptBuilder`) | выполнено (Phase 2) |
| `OpenAIModelsService` | выполнено (PR 3) |
| `OpenAITranslationService` / format split | **не сделано** |
| `OpenAIOCRService` vs Vision boundary | **не сделано** (PR 4) |
| `OpenAIStudyService` | **не сделано** |
| `OpenAIService.swift` не монолит | частично (DTO/settings/keychain остаются) |
| Responses API / structured outputs migration | **не сделано** (после Context7 review) |
| Timeout / cancellation в HTTP client | **не сделано** |

## Следующий шаг

**Phase 6 PR 4** — `OpenAIOCRService`: вынести `recognizeTextInImage` за OCR boundary (`OCRServing` vs AI OCR).

Далее PR 5: опциональная миграция endpoint (Responses API) после review документации.

## See Also

- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — `OpenAIPromptBuilder`, `OpenAIServiceError`, `OpenAIServing`, `Data/OpenAI`
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — `ManageOpenAISettingsUseCase` → `fetchModels`
- [Refactoring Phase 5 SQLite Persistence](refactoring-phase-5-sqlite-persistence.md) — Phase 5 перед Phase 6
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — карта OpenAI-вызовов
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — архивный полный план Phase 6–10
