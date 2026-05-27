//
//  HistoryDatabaseSchema.swift
//  llh
//

import Foundation
import GRDB

enum HistoryDatabaseSchema {
    static let metaTable = "history_store_meta"
    static let profilesTable = "learning_profiles"
    static let entriesTable = "history_entries"

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_history_schema") { db in
            try db.create(table: metaTable) { table in
                table.primaryKey("id", .integer)
                table.column("selected_profile_id", .text)
                table.column("json_migration_completed", .integer).notNull().defaults(to: 0)
            }
            try db.execute(
                sql: """
                INSERT INTO \(metaTable) (id, json_migration_completed)
                VALUES (1, 0)
                """
            )

            try db.create(table: profilesTable) { table in
                table.primaryKey("id", .text)
                table.column("name", .text).notNull()
                table.column("learning_language", .text).notNull()
                table.column("kind", .text).notNull()
                table.column("created_at", .double).notNull()
                table.column("selected_entry_id", .text)
                table.column("profile_sort_index", .integer).notNull()
            }

            try db.create(table: entriesTable) { table in
                table.primaryKey("id", .text)
                table.column("profile_id", .text)
                    .notNull()
                    .references(profilesTable, onDelete: .cascade)
                table.column("text", .text).notNull()
                table.column("formatted_text_json", .text)
                table.column("formatting_status", .text).notNull()
                table.column("study_materials_json", .text).notNull()
                table.column("created_at", .double).notNull()
                table.column("entry_sort_index", .integer).notNull()
            }
        }
        migrator.registerMigration("v2_profile_session_automation") { db in
            try db.alter(table: profilesTable) { table in
                table.add(column: "auto_load_words", .integer).notNull().defaults(to: 0)
                table.add(column: "auto_load_grammar", .integer).notNull().defaults(to: 0)
            }
        }
        migrator.registerMigration("v3_profile_overlay_words") { db in
            try db.alter(table: profilesTable) { table in
                table.add(column: "show_words_in_compact_overlay", .integer).notNull().defaults(to: 0)
            }
        }
        return migrator
    }
}
