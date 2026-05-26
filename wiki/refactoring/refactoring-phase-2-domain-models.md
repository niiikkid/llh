# Refactoring Phase 2 Domain Models

> Sources: llh project, 2026-05-26
> Raw: [Phase 2 domain models completion](../../raw/refactoring/2026-05-26-phase-2-domain-models-completion.md); [Phase 2 Data/OpenAI completion](../../raw/refactoring/2026-05-26-phase-2-data-openai-completion.md)
> Updated: 2026-05-26

## Overview

Phase 2 («Extract Domain Models And Errors») **завершена по основным критериям roadmap** в два инкремента без изменения продуктового поведения:

1. **Инкремент 1** — product-модели из `MainViewModel.swift` → `llh/Domain/Models/` (`MainViewModel` ~1316 → ~744 строк).
2. **Инкремент 2** — JSON snapshot и OpenAI-границы в Data: `HistoryStoreSnapshot`, `OpenAIModel`, `OpenAIServiceError`, `OpenAIPromptBuilder`; протокол `OpenAIServing` → `Domain/Services/`. Промпты убраны из `LearningLanguage`.

Опционально остаётся расширить `Domain/Errors` для **workflow**-ошибок (отдельно от `OpenAIServiceError` в Data). **Phase 5** — SQLite в `Data/Persistence/` — см. [Phase 5](refactoring-phase-5-sqlite-persistence.md). **Phase 6 завершена** — `OpenAIHTTPClient`, models/OCR/translation/study services, `OpenAITokenStore`, `OpenAISettingsStore` — см. [Phase 6](refactoring-phase-6-openai-integration.md). **Phase 7 завершена** — `OCRResult`, `VisionOCRService`, `OCRImagePreprocessor` — см. [Phase 7](refactoring-phase-7-ocr-capture-permission.md).

## Инкремент 1 — Domain/Models

| Файл | Содержимое |
|------|------------|
| `FormattingStatus.swift` | Статусы форматирования и study |
| `LearningLanguage.swift` | Язык сессии (UI: `title`, `supportsWordStudy`) |
| `OCREngine.swift` | local / AI |
| `OCRResult.swift` | Structured OCR: `text`, `lines`, `isEmpty` (Phase 7) |
| `ScreenRecordingPermissionStatus.swift` | `.authorized` / `.denied` (Phase 7) |
| `StructuredFormattedText.swift` | Очищенный текст, пиньинь, перевод |
| `StudyMaterials.swift` | Study payloads, legacy `StudyAssistantData` decode |
| `CapturedTextEntry.swift` | Запись истории, legacy `Codable`, `NSImage?` только in-memory |
| `LearningProfile.swift` | Профиль, `LearningProfileKind`, default profile |
| `SessionReadingSequenceItem.swift` | Режим «вся сессия» |
| `TranslationOverlayTiming.swift` | `LatestTranslationLookup`, расчёт длительности overlay |

## Инкремент 2 — Data и OpenAI

### Data/Persistence

| Файл | Содержимое |
|------|------------|
| `HistoryStoreSnapshot.swift` | On-disk JSON для `history.json` (не domain entity) |

`HistoryPersistenceService` сохраняет load/save и legacy-миграцию из массива записей.

### Data/OpenAI

| Файл | Содержимое |
|------|------------|
| `OpenAIModel.swift` | Модель для списка в настройках |
| `OpenAIServiceError.swift` | Ошибки API с русскими `LocalizedError` (вкл. `rateLimited`, `timeout`, `cancelled`) |
| `OpenAIPromptBuilder.swift` | Все промпты: format, AI OCR, words/phrases/grammar, pinyin rules, instruction names |
| `OpenAIHTTPClient.swift` | HTTP transport для `/v1/*` (Phase 6 PR 2) |
| `OpenAIModelsService.swift` | `GET /models`, listing для settings/validation (Phase 6 PR 3) |
| `OpenAIOCRService.swift` | Vision `POST /chat/completions` для AI OCR (Phase 6 PR 4) |
| `OpenAITranslationService.swift` | Format recognized text (Phase 6 PR 5) |
| `OpenAIStudyService.swift` | Words/phrases/grammar study (Phase 6 PR 5) |
| `OpenAIChatCompletionClient.swift` | Shared text Chat Completions + JSON extract (Phase 6 PR 5) |
| `OpenAITokenStore.swift` | Keychain token storage (Phase 6 PR 6) |
| `OpenAISettingsStore.swift` | UserDefaults settings store (Phase 6 PR 6) |

### Domain/Services

| Файл | Содержимое |
|------|------------|
| `OpenAIServing.swift` | Протокол OpenAI-операций (format, study, models, OCR facade) |
| `OpenAIOCRServing.swift` | Протокол AI OCR (Phase 6 PR 4); возвращает `OCRResult` (Phase 7) |

### Infrastructure (Phase 7)

| Путь | Содержимое |
|------|------------|
| `Infrastructure/OCR/VisionOCRService.swift` | Локальный Vision OCR |
| `Infrastructure/OCR/OCRImagePreprocessor.swift` | JPEG для AI OCR |
| `Infrastructure/Capture/ScreenCaptureKitCaptureService.swift` | ScreenCaptureKit capture |

`OpenAIService` — чистый фасад `OpenAIServing`: `fetchModels` → `OpenAIModelsService`; `recognizeTextInImage` → `OpenAIOCRService`; format → `OpenAITranslationService`; study → `OpenAIStudyService`. Settings/keychain — `OpenAISettingsStore` / `KeychainOpenAITokenStore` в `Data/OpenAI/` (PR 6).

## MainViewModel

- После Phase 3: ~783 строк; все workflows делегированы use cases; `HistorySessionState` в `Domain/Models`
- После Phase 4 inc. 1: ~685 строк Main + `SettingsViewModel`; settings UI state в `Presentation/Settings/`
- После Phase 4 inc. 2: ~509 строк Main + `HistoryViewModel` + `SettingsViewModel`; history UI state в `Presentation/History/`
- После Phase 4 inc. 3: ~439 строк Main + `CaptureViewModel` + `AppShortcutsCoordinator`; capture/permission UI state в `Presentation/Capture/`
- После Phase 4 inc. 4: ~307 строк Main + `StudyViewModel` + `TranslationOverlayCoordinator`; study UI state в `Presentation/Study/`
- После Phase 4 inc. 5: ~157 строк Main + `EditorViewModel` (~198 строк); editor/format UI state в `Presentation/Editor/`
- DI из Phase 1: `AppDependencyContainer` → `init(dependencies:)`

## Покрытие тестами

`llhTests/Phase2DomainModelsTests.swift`:

- `LearningProfile.defaultProfile()` — `.auto`, `.default`, `isDefaultProfile`
- `StructuredFormattedText.sessionListSourceDisplay` — пиньинь для `.chinese`
- `TranslationOverlayTiming.duration` — clamp минимума (1 с)
- `openAIPromptBuilder_formatRecognizedTextUserPrompt_includesRawText`
- `historyStoreSnapshot_roundtripsThroughJSON`

`RefactorBaselineTests` / `llhTests.swift` — prompt и error coverage через `OpenAIPromptBuilder` и `OpenAIServiceError`.

## Критерии выхода Phase 2

| Критерий | Статус |
|----------|--------|
| Модели не в `MainViewModel.swift` | выполнено |
| Legacy history decode на `CapturedTextEntry` | выполнено |
| Без изменения продуктового поведения | выполнено |
| Prompt-строки вне `LearningLanguage` | выполнено |
| Persistence snapshots в Data | выполнено |
| `OpenAIModel` / `OpenAIServiceError` в Data/OpenAI | выполнено |
| `OpenAIServing` в Domain | выполнено |
| `Domain/Errors` (workflow) | опционально, не блокирует Phase 3 |

## See Also

- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md) — `OCRResult`, Infrastructure OCR/capture (завершена)
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md) — `OpenAIHTTPClient`, models/OCR/translation/study services
- [Refactoring Phase 5 SQLite Persistence](refactoring-phase-5-sqlite-persistence.md) — SQLite слой для snapshot
- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md) — Phase 4 завершена
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — Phase 3 завершена
- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md) — DI и repositories
- [Refactoring Phase 0 Baseline](refactoring-phase-0-baseline.md) — инвентарь и safety net
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — полный план (архивный snapshot)
