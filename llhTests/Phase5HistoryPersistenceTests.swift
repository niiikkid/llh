//
//  Phase5HistoryPersistenceTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase5HistoryPersistenceTests {
  private func makeTemporaryLocations() -> HistoryStorageLocations {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return HistoryStorageLocations(applicationSupportDirectory: directory)
  }

  @Test
  func sqliteHistoryRepository_roundtripsSnapshot() throws {
    let locations = makeTemporaryLocations()
    let database = try HistoryDatabase(locations: locations)
    let repository = SQLiteHistoryRepository(database: database)
    let entry = CapturedTextEntry(
      text: "你好",
      formattedText: StructuredFormattedText(
        cleanedText: "你好",
        pinyinText: "nǐ hǎo",
        russianTranslation: "привет"
      ),
      formattingStatus: .succeeded,
      studyMaterials: StudyMaterials(
        words: WordStudyPayload(entries: []),
        wordsStatus: .succeeded
      )
    )
    let profile = LearningProfile.defaultProfile(history: [entry], selectedEntryID: entry.id)
    let snapshot = HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)

    try repository.saveStore(snapshot)
    let loaded = try repository.loadStore()

    #expect(loaded.profiles.count == 1)
    #expect(loaded.profiles[0].history.count == 1)
    #expect(loaded.profiles[0].history[0].text == "你好")
    #expect(loaded.profiles[0].history[0].formattedText?.russianTranslation == "привет")
    #expect(loaded.selectedProfileID == profile.id)
    #expect(loaded.profiles[0].history[0].image == nil)
  }

  @Test
  func sqliteHistoryRepository_roundtripsSessionAutomationFlags() throws {
    let locations = makeTemporaryLocations()
    let database = try HistoryDatabase(locations: locations)
    let repository = SQLiteHistoryRepository(database: database)
    let profile = LearningProfile(
      name: "Auto",
      learningLanguage: .chinese,
      automaticallyLoadWords: true,
      automaticallyLoadGrammar: true,
      showWordsInCompactOverlay: true
    )
    let snapshot = HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)

    try repository.saveStore(snapshot)
    let loaded = try repository.loadStore()

    #expect(loaded.profiles[0].automaticallyLoadWords)
    #expect(loaded.profiles[0].automaticallyLoadGrammar)
    #expect(loaded.profiles[0].showWordsInCompactOverlay)
  }

  @Test
  func sqliteHistoryRepository_emptyDatabaseReturnsDefaultProfile() throws {
    let locations = makeTemporaryLocations()
    let database = try HistoryDatabase(locations: locations)
    let repository = SQLiteHistoryRepository(database: database)

    let loaded = try repository.loadStore()

    #expect(loaded.profiles.count == 1)
    #expect(loaded.profiles[0].isDefaultProfile)
    #expect(loaded.selectedProfileID == loaded.profiles[0].id)
  }

  @Test
  func historyMigrationService_importsJSONAndIsIdempotent() throws {
    let locations = makeTemporaryLocations()
    try locations.ensureDirectoryExists()

    let jsonPersistence = HistoryPersistenceService(fileURL: locations.jsonFileURL)
    let jsonRepository = JSONHistoryRepository(persistence: jsonPersistence)
    let profile = LearningProfile(
      name: "Spanish",
      learningLanguage: .spanish,
      history: [CapturedTextEntry(text: "hola")],
      selectedEntryID: nil
    )
    let snapshot = HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)
    try jsonRepository.saveStore(snapshot)

    let database = try HistoryDatabase(locations: locations)
    let sqliteRepository = SQLiteHistoryRepository(database: database)
    let migrationService = HistoryMigrationService(
      database: database,
      jsonRepository: jsonRepository,
      sqliteRepository: sqliteRepository,
      jsonFileURL: locations.jsonFileURL
    )

    try migrationService.migrateIfNeeded()
    #expect(try database.isJSONMigrationCompleted())
    #expect(try database.profileCount() == 1)
    #expect(try database.entryCount() == 1)

    let loaded = try sqliteRepository.loadStore()
    #expect(loaded.profiles[0].history.first?.text == "hola")

    try migrationService.migrateIfNeeded()
    #expect(try database.entryCount() == 1)
  }

  @Test
  func historyMigrationService_freshInstallMarksMigrationWithoutJSON() throws {
    let locations = makeTemporaryLocations()
    let database = try HistoryDatabase(locations: locations)
    let jsonRepository = JSONHistoryRepository(
      persistence: HistoryPersistenceService(fileURL: locations.jsonFileURL)
    )
    let sqliteRepository = SQLiteHistoryRepository(database: database)
    let migrationService = HistoryMigrationService(
      database: database,
      jsonRepository: jsonRepository,
      sqliteRepository: sqliteRepository,
      jsonFileURL: locations.jsonFileURL
    )

    try migrationService.migrateIfNeeded()

    #expect(try database.isJSONMigrationCompleted())
    #expect(FileManager.default.fileExists(atPath: locations.jsonFileURL.path) == false)
  }

  @Test
  func historyRepositoryBootstrap_migratesJSONAndReadsSQLite() throws {
    let locations = makeTemporaryLocations()
    try locations.ensureDirectoryExists()

    let jsonRepository = JSONHistoryRepository(
      persistence: HistoryPersistenceService(fileURL: locations.jsonFileURL)
    )
    let entry = CapturedTextEntry(text: "persisted")
    let profile = LearningProfile.defaultProfile(history: [entry], selectedEntryID: entry.id)
    try jsonRepository.saveStore(
      HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)
    )

    let repository = HistoryRepositoryBootstrap.makeRepository(locations: locations)
    let loaded = try repository.loadStore()

    #expect(loaded.profiles[0].history.first?.text == "persisted")
    #expect(FileManager.default.fileExists(atPath: locations.jsonFileURL.path))
    #expect(FileManager.default.fileExists(atPath: locations.databaseFileURL.path))
  }

  @Test
  @MainActor
  func manageHistoryUseCase_worksWithSQLiteRepository() throws {
    let locations = makeTemporaryLocations()
    let database = try HistoryDatabase(locations: locations)
    let repository = SQLiteHistoryRepository(database: database)
    let useCase = ManageHistoryUseCase(historyRepository: repository)

    var state = try useCase.loadSession()
    #expect(state.profiles.isEmpty == false)

    let entry = CapturedTextEntry(text: "new capture")
    useCase.insertEntry(state: &state, profileIndex: 0, entry: entry)
    try useCase.saveSession(state)

    let reloaded = try useCase.loadSession()
    #expect(reloaded.profiles[0].history.first?.text == "new capture")
  }
}
