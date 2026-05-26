//
//  HistoryRepositoryBootstrap.swift
//  llh
//

import Foundation

enum HistoryRepositoryBootstrap {
    /// Opens SQLite, runs JSON→SQLite migration when needed, returns SQLite-backed repository.
    /// Falls back to JSON-only repository if the database cannot be opened.
    static func makeRepository(fileManager: FileManager = .default) -> HistoryRepository {
        makeRepository(locations: HistoryStorageLocations(fileManager: fileManager), fileManager: fileManager)
    }

    static func makeRepository(
        locations: HistoryStorageLocations,
        fileManager: FileManager = .default
    ) -> HistoryRepository {
        let jsonPersistence = HistoryPersistenceService(fileURL: locations.jsonFileURL)
        let jsonRepository = JSONHistoryRepository(persistence: jsonPersistence)

        do {
            let database = try HistoryDatabase(locations: locations, fileManager: fileManager)
            let sqliteRepository = SQLiteHistoryRepository(database: database)
            let migrationService = HistoryMigrationService(
                database: database,
                jsonRepository: jsonRepository,
                sqliteRepository: sqliteRepository,
                jsonFileURL: locations.jsonFileURL,
                fileManager: fileManager
            )
            try migrationService.migrateIfNeeded()
            return sqliteRepository
        } catch {
            return jsonRepository
        }
    }
}
