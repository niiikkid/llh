# Phase 5 SQLite history persistence completion

> Source: llh project implementation (Phase 5, PR 1–4 scope)
> Collected: 2026-05-26
> Published: 2026-05-26

## Summary

Implemented SQLite-backed history persistence with GRDB, one-time JSON→SQLite migration, and startup wiring. `history.json` is preserved as backup and never deleted during migration.

## Dependencies

- SPM: `GRDB.swift` ≥ 7.0 (`https://github.com/groue/GRDB.swift`)

## New / changed files

| Path | Role |
|------|------|
| `llh/Data/Persistence/HistoryStorageLocations.swift` | `Application Support/llh/history.json` + `history.sqlite` |
| `llh/Data/Persistence/HistoryDatabaseSchema.swift` | GRDB `DatabaseMigrator`, migration `v1_history_schema` |
| `llh/Data/Persistence/HistoryDatabase.swift` | `DatabaseQueue`, `json_migration_completed` flag |
| `llh/Data/Persistence/HistorySnapshotCodec.swift` | JSON encode/decode for `formattedText` / `studyMaterials` blobs |
| `llh/Data/Persistence/HistoryMigrationService.swift` | Idempotent JSON import + verification |
| `llh/Data/Repositories/SQLiteHistoryRepository.swift` | `HistoryRepository` over SQLite |
| `llh/App/HistoryRepositoryBootstrap.swift` | Open DB, migrate, return SQLite repo; JSON fallback on failure |
| `llh/App/AppDependencyContainer.swift` | `live()` uses `HistoryRepositoryBootstrap.makeRepository()` |
| `llhTests/Phase5HistoryPersistenceTests.swift` | Roundtrip, migration, bootstrap, use case integration |

Unchanged as backup/source: `JSONHistoryRepository`, `HistoryPersistenceService`, `HistoryStoreSnapshot`.

## Schema v1

Tables:

- `history_store_meta` (single row `id=1`): `selected_profile_id`, `json_migration_completed`
- `learning_profiles`: profile fields + `profile_sort_index`
- `history_entries`: entry fields + `formatted_text_json`, `study_materials_json`, `entry_sort_index`, FK `profile_id` ON DELETE CASCADE

Screenshots remain out of persistence (`image` always `nil` on load).

## Migration rules

1. Skip if `json_migration_completed == 1`.
2. If `history.json` exists: load via `JSONHistoryRepository`, `saveStore` to SQLite, verify profile/entry counts and IDs, then set flag.
3. Fresh install (no JSON): set flag without import.
4. Never delete or overwrite `history.json`.

## Bootstrap

`HistoryRepositoryBootstrap.makeRepository()` → SQLite after successful migration; on any error opening/migrating DB, falls back to `JSONHistoryRepository`.

## Tests (`Phase5HistoryPersistenceTests`)

- SQLite roundtrip with formatted text + study materials
- Empty DB → default profile
- JSON import + idempotent second run
- Fresh install marks migration without JSON file
- Bootstrap migrates and reads from SQLite
- `ManageHistoryUseCase` with SQLite repository

## Not in this increment (roadmap remainder)

- Async persistence off main thread
- User-visible error for corrupt JSON at migration
- Dedicated legacy-format migration tests on SQLite path
- Optional `history.json` cleanup (requires explicit approval)

## Ancillary compile fixes (same session)

- `ManageOpenAISettingsUseCase` → `final class`; `UserDefaultsSettingsRepository` → `final class`
- `import Combine` in Capture/Study/Editor ViewModels
- `MainViewModel` shortcuts init: capture `overlay`/`settings` instead of `self` before init complete
- `@MainActor` on `Phase3ManageProfilesUseCaseTests` struct

## Build status

- `xcodebuild build` (scheme `llh`, macOS): **succeeded**
- Full test target: some pre-existing Phase 3 test compile issues unrelated to Phase 5 files
