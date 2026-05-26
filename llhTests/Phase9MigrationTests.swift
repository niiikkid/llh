//
//  Phase9MigrationTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase9MigrationTests {
    @Test
    func historyMigrationService_throwsWhenVerificationDetectsMismatch() throws {
        let locations = Phase9TestSupport.makeTemporaryLocations()
        try locations.ensureDirectoryExists()

        let jsonRepository = JSONHistoryRepository(
            persistence: HistoryPersistenceService(fileURL: locations.jsonFileURL)
        )
        let entry = CapturedTextEntry(text: "hola")
        let profile = LearningProfile(
            name: "Spanish",
            learningLanguage: .spanish,
            history: [entry],
            selectedEntryID: entry.id
        )
        try jsonRepository.saveStore(
            HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)
        )

        let database = try HistoryDatabase(locations: locations)
        let sqliteRepository = SQLiteHistoryRepository(database: database)
        let mismatchRepository = Phase9MismatchOnLoadHistoryRepository(inner: sqliteRepository)
        let migrationService = HistoryMigrationService(
            database: database,
            jsonRepository: jsonRepository,
            sqliteRepository: mismatchRepository,
            jsonFileURL: locations.jsonFileURL
        )

        #expect(throws: HistoryPersistenceError.migrationVerificationFailed) {
            try migrationService.migrateIfNeeded()
        }
        #expect(try database.isJSONMigrationCompleted() == false)
        // Import may write to SQLite before verification fails; flag must stay unset.
        #expect(try database.entryCount() == 1)
    }

    @Test
    func historyRepositoryBootstrap_fallsBackToJSONWhenDatabaseFileIsCorrupt() throws {
        let locations = Phase9TestSupport.makeTemporaryLocations()
        try locations.ensureDirectoryExists()

        let jsonRepository = JSONHistoryRepository(
            persistence: HistoryPersistenceService(fileURL: locations.jsonFileURL)
        )
        let entry = CapturedTextEntry(text: "from-json")
        let profile = LearningProfile.defaultProfile(history: [entry], selectedEntryID: entry.id)
        try jsonRepository.saveStore(
            HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)
        )

        try Data([0x00, 0x01, 0x02]).write(to: locations.databaseFileURL)

        let repository = HistoryRepositoryBootstrap.makeRepository(locations: locations)
        let loaded = try repository.loadStore()

        #expect(loaded.profiles[0].history.first?.text == "from-json")
        #expect(FileManager.default.fileExists(atPath: locations.databaseFileURL.path))
    }
}
