//
//  HistoryPersistenceService.swift
//  llh
//

import Foundation

struct HistoryStoreSnapshot: Codable {
    var profiles: [LearningProfile]
    var selectedProfileID: LearningProfile.ID?
}

struct HistoryPersistenceService {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            self.fileURL = appSupport
                .appendingPathComponent("llh", isDirectory: true)
                .appendingPathComponent("history.json", isDirectory: false)
        }
    }

    func loadStore() throws -> HistoryStoreSnapshot {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            let defaultProfile = LearningProfile(name: "Основной")
            return HistoryStoreSnapshot(profiles: [defaultProfile], selectedProfileID: defaultProfile.id)
        }
        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        if let snapshot = try? decoder.decode(HistoryStoreSnapshot.self, from: data),
           !snapshot.profiles.isEmpty {
            return snapshot
        }

        // Backward compatibility with old history-only format.
        let legacyRecords = try decoder.decode([StoredHistoryRecord].self, from: data)
        let legacyEntries = legacyRecords.map { record in
            CapturedTextEntry(id: record.id, text: record.text, createdAt: record.createdAt, image: nil)
        }
        let migratedProfile = LearningProfile(
            name: "Основной",
            history: legacyEntries,
            selectedEntryID: legacyEntries.first?.id
        )
        return HistoryStoreSnapshot(profiles: [migratedProfile], selectedProfileID: migratedProfile.id)
    }

    func saveStore(_ snapshot: HistoryStoreSnapshot) throws {
        let folderURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}

private struct StoredHistoryRecord: Codable {
    let id: UUID
    let text: String
    let createdAt: Date
}
