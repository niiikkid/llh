//
//  HistoryDatabase.swift
//  llh
//

import Foundation
import GRDB

/// SQLite access for history persistence (GRDB `DatabaseQueue`).
final class HistoryDatabase: @unchecked Sendable {
    let dbQueue: DatabaseQueue
    let locations: HistoryStorageLocations

    init(locations: HistoryStorageLocations, fileManager: FileManager = .default) throws {
        self.locations = locations
        try locations.ensureDirectoryExists(fileManager: fileManager)
        let queue = try DatabaseQueue(path: locations.databaseFileURL.path)
        try HistoryDatabaseSchema.migrator.migrate(queue)
        self.dbQueue = queue
    }

    func isJSONMigrationCompleted() throws -> Bool {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT json_migration_completed FROM \(HistoryDatabaseSchema.metaTable)
                WHERE id = 1
                """
            ) == 1
        }
    }

    func setJSONMigrationCompleted(_ completed: Bool) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE \(HistoryDatabaseSchema.metaTable)
                SET json_migration_completed = ?
                WHERE id = 1
                """,
                arguments: [completed ? 1 : 0]
            )
        }
    }

    func profileCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM \(HistoryDatabaseSchema.profilesTable)"
            ) ?? 0
        }
    }

    func entryCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM \(HistoryDatabaseSchema.entriesTable)"
            ) ?? 0
        }
    }
}
