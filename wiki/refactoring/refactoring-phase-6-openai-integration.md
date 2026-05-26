# Refactoring Phase 6 OpenAI Integration

> Sources: llh project, 2026-05-26; OpenAI API documentation (Context7), 2026-05-26
> Raw: [Phase 6 OpenAI HTTP client completion](../../raw/refactoring/2026-05-26-phase-6-openai-http-client-completion.md); [Phase 6 OpenAI models service completion](../../raw/refactoring/2026-05-26-phase-6-openai-models-service-completion.md); [Phase 6 OpenAI OCR service completion](../../raw/refactoring/2026-05-26-phase-6-openai-ocr-service-completion.md); [Phase 6 translation and study services completion](../../raw/refactoring/2026-05-26-phase-6-translation-study-services-completion.md); [Phase 6 settings/keychain and timeout completion](../../raw/refactoring/2026-05-26-phase-6-settings-keychain-timeout-completion.md)
> Updated: 2026-05-27

## Overview

Phase 6 («OpenAI Integration Modernization») **завершена**. PR 1 (промпты) — Phase 2 (`OpenAIPromptBuilder`). PR 2–5 — HTTP, models, OCR, translation/study. **PR 6** — settings/keychain в `Data/OpenAI/`, timeout/cancellation в `OpenAIHTTPClient`. `OpenAIService` — чистый фасад `OpenAIServing`. Endpoint — Chat Completions + Models API. **Responses API отложен** (Context7: incremental migration; vision/multimodal — отдельная задача).

## Слой Data/OpenAI

```text
OpenAIService (Services/) — OpenAIServing facade only
  ├── OpenAIHTTPClient           — GET/POST /v1/*, errors, timeout, cancellation
  ├── OpenAIModelsService        — GET /models → [OpenAIModel]
  ├── OpenAIOCRService           — vision POST /chat/completions
  ├── OpenAITranslationService   — format POST /chat/completions
  ├── OpenAIStudyService         — words/phrases/grammar
  └── OpenAIChatCompletionClient — shared text completions + JSON extract

OpenAITokenStore.swift           — Keychain token storage (PR 6)
OpenAISettingsStore.swift        — UserDefaults-backed settings (PR 6)

Domain/Services/OpenAIOCRServing — AI OCR boundary (RecognizeTextUseCase)
```

| Файл | Назначение |
|------|------------|
| `OpenAIHTTPClient.swift` | Transport (PR 2); timeout/cancellation (PR 6) |
| `OpenAIModelsService.swift` | Model listing + empty-list guard (PR 3) |
| `OpenAIOCRService.swift` | AI OCR vision request (PR 4) |
| `OpenAITranslationService.swift` | Format recognized text (PR 5) |
| `OpenAIStudyService.swift` | Word/phrase/grammar study (PR 5) |
| `OpenAIChatCompletionClient.swift` | Text Chat Completions + JSON from content (PR 5) |
| `OpenAITokenStore.swift` | `OpenAITokenStoring`, `KeychainOpenAITokenStore` (PR 6) |
| `OpenAISettingsStore.swift` | UserDefaults settings store (PR 6) |
| `Domain/Services/OpenAIOCRServing.swift` | Протокол AI OCR для `RecognizeTextUseCase` (PR 4) |
| `OpenAIModel.swift` | Domain-facing model id |
| `OpenAIServiceError.swift` | Typed API errors (вкл. `rateLimited`, `timeout`, `cancelled`) |
| `OpenAIPromptBuilder.swift` | Все промпты (Phase 2) |

## Инкремент 5 — Settings/Keychain и HTTP polish (PR 6, завершён)

| Изменение | Поведение |
|-----------|-----------|
| `OpenAITokenStore.swift` | `OpenAITokenStoring`, `KeychainOpenAITokenStore`, `OpenAITokenStoreError` — вынесены из `OpenAIService.swift` |
| `OpenAISettingsStore.swift` | UserDefaults store для model/OCR/overlay settings — вынесен из `OpenAIService.swift` |
| `OpenAIService.swift` | Только фасад `OpenAIServing`; без Keychain/Security |
| `OpenAIHTTPClient` | `requestTimeout` default 120s; `Task.checkCancellation()`; `URLError.timedOut` → `.timeout`; `URLError.cancelled` → `.cancelled`; `CancellationError` пробрасывается |

Repositories (`KeychainAPIKeyRepository`, `UserDefaultsSettingsRepository`) по-прежнему используют вынесенные типы из `Data/OpenAI/`.

## Инкремент 2 — OpenAIModelsService (PR 3)

| Шаг | Поведение |
|-----|-----------|
| HTTP | `GET /models` через общий `OpenAIHTTPClient` |
| Decode | `{ "object": "list", "data": [{ "id": "..." }, ...] }` |
| Map | `data[].id` → `OpenAIModel` |
| Sort | `localizedStandardCompare` по `id` |
| Empty | `OpenAIServiceError.noModelsFound` |

## Инкремент 3 — OpenAIOCRService (PR 4)

| Шаг | Поведение |
|-----|-----------|
| Image | JPEG encode → `data:image/jpeg;base64,...` |
| Request | `POST /chat/completions`, text prompt + `image_url` |
| Response | `choices[0].message.content` → normalize |

`RecognizeTextUseCase`: `.local` → `OCRServing` (`VisionOCRService`); `.ai` → `OpenAIOCRServing`; оба возвращают `OCRResult` (Phase 7).

## Инкремент 1 — OpenAIHTTPClient (PR 2 + PR 6)

| HTTP | → `OpenAIServiceError` |
|------|-------------------------|
| 401 | `unauthorized` |
| 429 | `rateLimited` |
| other non-2xx | `unexpectedStatusCode` |
| DNS / host | `hostNotFound` |
| offline | `networkUnavailable` |
| timed out | `timeout` |
| cancelled | `cancelled` |

Base URL: `https://api.openai.com/v1`. Default timeout: 120s.

## Инкремент 4 — Translation and Study (PR 5)

| Сервис | Поведение |
|--------|-----------|
| `OpenAIChatCompletionClient` | `POST /chat/completions`, JSON extract |
| `OpenAITranslationService` | `formatRecognizedText`; temperature 0 |
| `OpenAIStudyService` | words/phrases/grammar; temperature 0.2 |

## Покрытие тестами

| Target | Файл | Сценарии |
|--------|------|----------|
| HTTP client | `Phase6OpenAIHTTPClientTests.swift` (12) | token; GET; 401/429/500; URLError; timeout interval; timeout; cancelled; task cancellation |
| Models service | `Phase6OpenAIModelsServiceTests.swift` (3) | сортировка; пустой `data`; 401 |
| OCR service | `Phase6OpenAIOCRServiceTests.swift` (4) | vision POST; normalize; empty; 401 |
| Translation service | `Phase6OpenAITranslationServiceTests.swift` (4) | format POST; empty; 401 |
| Study service | `Phase6OpenAIStudyServiceTests.swift` (3) | words POST; empty; 401 |
| Baseline | `RefactorBaselineTests` | error descriptions incl. `timeout`, `cancelled` |

## Критерии выхода Phase 6 (roadmap)

| Критерий | Статус |
|----------|--------|
| `OpenAIHTTPClient` — transport отдельно | ✅ PR 2 |
| Prompts centralized (`OpenAIPromptBuilder`) | ✅ Phase 2 |
| `OpenAIModelsService` | ✅ PR 3 |
| `OpenAITranslationService` / format split | ✅ PR 5 |
| `OpenAIOCRService` vs Vision boundary | ✅ PR 4 |
| `OpenAIStudyService` | ✅ PR 5 |
| `OpenAIService.swift` не монолит | ✅ PR 6 (facade only) |
| Settings/keychain вне HTTP-слоя | ✅ PR 6 |
| Timeout / cancellation в HTTP client | ✅ PR 6 |
| Responses API migration | **отложено** — Context7: Chat Completions supported; vision migration отдельно |

## Следующий шаг

**Phase 7–8 завершены** — см. [Phase 8](refactoring-phase-8-ui-decomposition.md). **Phase 9** — testing strategy. Опционально позже: Responses API migration после отдельного плана для vision/multimodal.

## See Also

- [Refactoring Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md)
- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md) — Vision vs OpenAI OCR polish, `OCRResult` (завершена)
- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md) — DI, repositories, `AppDependencyContainer`
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md)
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md)
- [Refactoring Phase 5 SQLite Persistence](refactoring-phase-5-sqlite-persistence.md)
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md)
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md)
