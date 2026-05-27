//
//  SQLiteHistoryRepository.swift
//  llh
//

import Foundation
import GRDB

struct SQLiteHistoryRepository: HistoryRepository {
    private let database: HistoryDatabase

    init(database: HistoryDatabase) {
        self.database = database
    }

    func loadStore() throws -> HistoryStoreSnapshot {
        try database.dbQueue.read { db in
            let selectedProfileID = try String.fetchOne(
                db,
                sql: """
                SELECT selected_profile_id FROM \(HistoryDatabaseSchema.metaTable)
                WHERE id = 1
                """
            ).flatMap(UUID.init(uuidString:))

            let profileRows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM \(HistoryDatabaseSchema.profilesTable)
                ORDER BY profile_sort_index ASC
                """
            )

            if profileRows.isEmpty {
                let defaultProfile = LearningProfile.defaultProfile()
                return HistoryStoreSnapshot(
                    profiles: [defaultProfile],
                    selectedProfileID: defaultProfile.id
                )
            }

            var profiles: [LearningProfile] = []
            profiles.reserveCapacity(profileRows.count)

            for profileRow in profileRows {
                let profileIDString: String = profileRow["id"]
                guard let profileID = UUID(uuidString: profileIDString) else {
                    throw HistoryPersistenceError.invalidRow
                }

                let entryRows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT * FROM \(HistoryDatabaseSchema.entriesTable)
                    WHERE profile_id = ?
                    ORDER BY entry_sort_index ASC
                    """,
                    arguments: [profileIDString]
                )

                let history = try entryRows.map { try Self.entry(from: $0) }
                let name: String = profileRow["name"]
                let learningLanguageRaw: String = profileRow["learning_language"]
                let kindRaw: String = profileRow["kind"]
                let createdAt: Double = profileRow["created_at"]
                let selectedEntryID = (profileRow["selected_entry_id"] as String?)
                    .flatMap(UUID.init(uuidString:))

                guard let learningLanguage = LearningLanguage(rawValue: learningLanguageRaw),
                      let kind = LearningProfileKind(rawValue: kindRaw) else {
                    throw HistoryPersistenceError.invalidRow
                }

                let autoLoadWords: Int = profileRow["auto_load_words"] ?? 0
                let autoLoadGrammar: Int = profileRow["auto_load_grammar"] ?? 0

                profiles.append(
                    LearningProfile(
                        id: profileID,
                        name: name,
                        learningLanguage: learningLanguage,
                        kind: kind,
                        createdAt: Date(timeIntervalSince1970: createdAt),
                        history: history,
                        selectedEntryID: selectedEntryID,
                        automaticallyLoadWords: autoLoadWords != 0,
                        automaticallyLoadGrammar: autoLoadGrammar != 0
                    )
                )
            }

            return HistoryStoreSnapshot(profiles: profiles, selectedProfileID: selectedProfileID)
        }
    }

    func saveStore(_ snapshot: HistoryStoreSnapshot) throws {
        try database.dbQueue.write { db in
            try db.execute(sql: "DELETE FROM \(HistoryDatabaseSchema.entriesTable)")
            try db.execute(sql: "DELETE FROM \(HistoryDatabaseSchema.profilesTable)")

            for (profileIndex, profile) in snapshot.profiles.enumerated() {
                try db.execute(
                    sql: """
                    INSERT INTO \(HistoryDatabaseSchema.profilesTable) (
                        id, name, learning_language, kind, created_at,
                        selected_entry_id, profile_sort_index,
                        auto_load_words, auto_load_grammar
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        profile.id.uuidString,
                        profile.name,
                        profile.learningLanguage.rawValue,
                        profile.kind.rawValue,
                        profile.createdAt.timeIntervalSince1970,
                        profile.selectedEntryID?.uuidString,
                        profileIndex,
                        profile.automaticallyLoadWords ? 1 : 0,
                        profile.automaticallyLoadGrammar ? 1 : 0,
                    ]
                )

                for (entryIndex, entry) in profile.history.enumerated() {
                    let formattedJSON = try HistorySnapshotCodec.encodeFormattedText(entry.formattedText)
                    let studyJSON = try HistorySnapshotCodec.encodeStudyMaterials(entry.studyMaterials)
                    try db.execute(
                        sql: """
                        INSERT INTO \(HistoryDatabaseSchema.entriesTable) (
                            id, profile_id, text, formatted_text_json, formatting_status,
                            study_materials_json, created_at, entry_sort_index
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            entry.id.uuidString,
                            profile.id.uuidString,
                            entry.text,
                            formattedJSON,
                            entry.formattingStatus.rawValue,
                            studyJSON,
                            entry.createdAt.timeIntervalSince1970,
                            entryIndex,
                        ]
                    )
                }
            }

            try db.execute(
                sql: """
                UPDATE \(HistoryDatabaseSchema.metaTable)
                SET selected_profile_id = ?
                WHERE id = 1
                """,
                arguments: [snapshot.selectedProfileID?.uuidString]
            )
        }
    }

    private static func entry(from row: Row) throws -> CapturedTextEntry {
        let idString: String = row["id"]
        guard let id = UUID(uuidString: idString) else {
            throw HistoryPersistenceError.invalidRow
        }
        let text: String = row["text"]
        let formattedJSON: String? = row["formatted_text_json"]
        let formattingStatusRaw: String = row["formatting_status"]
        let studyJSON: String = row["study_materials_json"]
        let createdAt: Double = row["created_at"]

        guard let formattingStatus = FormattingStatus(rawValue: formattingStatusRaw) else {
            throw HistoryPersistenceError.invalidRow
        }

        return CapturedTextEntry(
            id: id,
            text: text,
            formattedText: try HistorySnapshotCodec.decodeFormattedText(formattedJSON),
            formattingStatus: formattingStatus,
            studyMaterials: try HistorySnapshotCodec.decodeStudyMaterials(studyJSON),
            createdAt: Date(timeIntervalSince1970: createdAt),
            image: nil
        )
    }
}
