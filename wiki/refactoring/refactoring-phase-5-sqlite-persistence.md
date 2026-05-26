# Refactoring Phase 5 SQLite Persistence

> Sources: llh project, 2026-05-26
> Raw: [Phase 5 SQLite history persistence completion](../../raw/refactoring/2026-05-26-phase-5-sqlite-history-persistence-completion.md)
> Updated: 2026-05-26

## Overview

Phase 5 («History Persistence Migration To SQLite») **в основном завершена** по критериям roadmap PR 1–4: схема, GRDB-клиент, `SQLiteHistoryRepository`, однократная миграция JSON→SQLite, startup wiring. Протокол `HistoryRepository` не менялся — UI и `ManageHistoryUseCase` по-прежнему работают со `HistoryStoreSnapshot`. `history.json` остаётся backup и **не удаляется**.

Зависимость: **GRDB.swift** ≥ 7.0 (SPM).

## Пути хранения

`HistoryStorageLocations`:

| Файл | Путь |
|------|------|
| JSON backup | `~/Library/Application Support/llh/history.json` |
| SQLite | `~/Library/Application Support/llh/history.sqlite` |

## Слой Data/Persistence

```text
HistoryRepositoryBootstrap (App/)
  → HistoryDatabase (DatabaseQueue + migrator)
  → HistoryMigrationService (JSON → SQLite, один раз)
  → SQLiteHistoryRepository : HistoryRepository
  → JSONHistoryRepository (fallback / источник миграции)
```

| Компонент | Назначение |
|-----------|------------|
| `HistoryDatabaseSchema` | Миграция `v1_history_schema` |
| `HistorySnapshotCodec` | JSON blobs для `StructuredFormattedText` и `StudyMaterials` |
| `HistoryMigrationService` | Идемпотентный импорт + верификация counts/IDs |
| `HistoryPersistenceError` | `migrationVerificationFailed`, encoding/decoding |

## Схема v1

**`history_store_meta`** (одна строка `id = 1`):

- `selected_profile_id` — глобальный выбор профиля (как в JSON snapshot)
- `json_migration_completed` — `0` / `1`, явный флаг завершения миграции

**`learning_profiles`**: `id`, `name`, `learning_language`, `kind`, `created_at`, `selected_entry_id`, `profile_sort_index`

**`history_entries`**: `id`, `profile_id` (FK CASCADE), `text`, `formatted_text_json`, `formatting_status`, `study_materials_json`, `created_at`, `entry_sort_index`

Порядок записей в профиле восстанавливается по `entry_sort_index` (соответствует порядку массива `history` в domain).

## Миграция JSON → SQLite

1. Если `json_migration_completed == 1` — пропуск.
2. Если есть `history.json` — загрузка через `JSONHistoryRepository` (включая legacy repair в `HistoryPersistenceService`), запись в SQLite транзакцией, проверка числа профилей/записей и множества profile IDs, совпадение `selectedProfileID`.
3. Если JSON нет (fresh install) — только выставить флаг.
4. Флаг выставляется **только после** успешной верификации (или fresh path).
5. `history.json` не удаляется и не перезаписывается миграцией.

При ошибке открытия БД или миграции `HistoryRepositoryBootstrap` возвращает **JSON-only** repository (fallback).

## DI

`AppDependencyContainer.live()`:

```swift
let historyRepository = HistoryRepositoryBootstrap.makeRepository()
```

`ManageHistoryUseCase` / `ManageProfilesUseCase` / `HistoryViewModel` не знают, SQLite это или JSON.

## Тесты

`llhTests/Phase5HistoryPersistenceTests.swift`:

- roundtrip SQLite;
- пустая БД → default profile;
- миграция JSON + идемпотентность;
- fresh install без JSON;
- bootstrap + `ManageHistoryUseCase` на SQLite.

## Критерии выхода Phase 5 (roadmap)

| Критерий | Статус |
|----------|--------|
| SQLite schema + client | выполнено |
| `SQLiteHistoryRepository` | выполнено |
| `JSONHistoryRepository` как backup/источник | выполнено |
| `HistoryMigrationService` + флаг в meta | выполнено |
| Startup wiring | выполнено |
| UI не знает тип storage | выполнено |
| JSON backup сохранён | выполнено |
| Persistence async (не блокировать UI) | **не сделано** |
| Corrupt JSON → user-visible error | **не сделано** |
| Optional cleanup `history.json` | **не сделано** (только с явного одобрения) |

## Следующий шаг

**Phase 6–7 завершены** — см. [Phase 7](refactoring-phase-7-ocr-capture-permission.md). **Следующий этап — Phase 8** (UI decomposition).

Опционально в рамках Phase 5: async save/load, UX при битом JSON.

## See Also

- [Refactoring Phase 7 OCR Capture Permission](refactoring-phase-7-ocr-capture-permission.md) — OCR/capture после persistence (завершена)
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md) — OpenAI modernization (завершена)
- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md) — presentation split до persistence
- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — `ManageHistoryUseCase` как граница workflow
- [Refactoring Phase 1 Boundaries And DI](refactoring-phase-1-boundaries.md) — `HistoryRepository` protocol
- [Refactoring Phase 2 Domain Models](refactoring-phase-2-domain-models.md) — domain models vs `HistoryStoreSnapshot`
- [LLH Project Refactoring Roadmap](project-refactoring-roadmap.md) — архивный полный план
