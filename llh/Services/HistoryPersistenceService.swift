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
            let defaultProfile = LearningProfile.defaultProfile()
            return HistoryStoreSnapshot(profiles: [defaultProfile], selectedProfileID: defaultProfile.id)
        }
        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        if let snapshot = try? decoder.decode(HistoryStoreSnapshot.self, from: data),
           !snapshot.profiles.isEmpty {
            return normalized(snapshot)
        }

        // Backward compatibility with old history-only format.
        let legacyRecords = try decoder.decode([StoredHistoryRecord].self, from: data)
        let legacyEntries = legacyRecords.map { record in
            CapturedTextEntry(id: record.id, text: record.text, createdAt: record.createdAt, image: nil)
        }
        let migratedProfile = LearningProfile.defaultProfile(
            history: legacyEntries,
            selectedEntryID: legacyEntries.first?.id
        )
        return normalized(HistoryStoreSnapshot(profiles: [migratedProfile], selectedProfileID: migratedProfile.id))
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

    private func normalized(_ snapshot: HistoryStoreSnapshot) -> HistoryStoreSnapshot {
        var profiles = snapshot.profiles
        if !profiles.contains(where: \.isDefaultProfile) {
            profiles.insert(.defaultProfile(), at: 0)
        }
        if let defaultIndex = profiles.firstIndex(where: \.isDefaultProfile), defaultIndex != 0 {
            let defaultProfile = profiles.remove(at: defaultIndex)
            profiles.insert(defaultProfile, at: 0)
        }

        let selectedProfileID: LearningProfile.ID?
        if let selectedID = snapshot.selectedProfileID,
           profiles.contains(where: { $0.id == selectedID }) {
            selectedProfileID = selectedID
        } else {
            selectedProfileID = profiles.first?.id
        }

        return HistoryStoreSnapshot(profiles: profiles, selectedProfileID: selectedProfileID)
    }
}

private struct StoredHistoryRecord: Codable {
    let id: UUID
    let text: String
    let createdAt: Date
}
