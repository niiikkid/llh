//
//  HistoryMigrationService.swift
//  llh
//

import Foundation

/// One-time import from `history.json` into SQLite. JSON file is never deleted.
struct HistoryMigrationService {
    private let database: HistoryDatabase
    private let jsonRepository: JSONHistoryRepository
    private let sqliteRepository: any HistoryRepository
    private let jsonFileURL: URL
    private let fileManager: FileManager

    init(
        database: HistoryDatabase,
        jsonRepository: JSONHistoryRepository,
        sqliteRepository: any HistoryRepository,
        jsonFileURL: URL,
        fileManager: FileManager = .default
    ) {
        self.database = database
        self.jsonRepository = jsonRepository
        self.sqliteRepository = sqliteRepository
        self.jsonFileURL = jsonFileURL
        self.fileManager = fileManager
    }

    /// Idempotent: skips when migration flag is already set.
    func migrateIfNeeded() throws {
        if try database.isJSONMigrationCompleted() {
            return
        }

        if fileManager.fileExists(atPath: jsonFileURL.path) {
            let snapshot = try jsonRepository.loadStore()
            try sqliteRepository.saveStore(snapshot)
            try verifyImportedSnapshot(snapshot)
        }

        try database.setJSONMigrationCompleted(true)
    }

    private func verifyImportedSnapshot(_ expected: HistoryStoreSnapshot) throws {
        let loaded = try sqliteRepository.loadStore()
        let expectedProfileCount = expected.profiles.count
        let expectedEntryCount = expected.profiles.reduce(0) { $0 + $1.history.count }

        guard loaded.profiles.count == expectedProfileCount else {
            throw HistoryPersistenceError.migrationVerificationFailed
        }
        let loadedEntryCount = loaded.profiles.reduce(0) { $0 + $1.history.count }
        guard loadedEntryCount == expectedEntryCount else {
            throw HistoryPersistenceError.migrationVerificationFailed
        }

        let expectedProfileIDs = Set(expected.profiles.map(\.id))
        let loadedProfileIDs = Set(loaded.profiles.map(\.id))
        guard expectedProfileIDs == loadedProfileIDs else {
            throw HistoryPersistenceError.migrationVerificationFailed
        }

        if let expectedSelected = expected.selectedProfileID,
           loaded.selectedProfileID != expectedSelected {
            throw HistoryPersistenceError.migrationVerificationFailed
        }
    }
}
