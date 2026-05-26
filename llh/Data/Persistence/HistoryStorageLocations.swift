//
//  HistoryStorageLocations.swift
//  llh
//

import Foundation

/// Application Support paths for JSON backup and SQLite history store.
struct HistoryStorageLocations: Sendable {
    let applicationSupportDirectory: URL
    let jsonFileURL: URL
    let databaseFileURL: URL

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let llhDirectory = appSupport.appendingPathComponent("llh", isDirectory: true)
        applicationSupportDirectory = llhDirectory
        jsonFileURL = llhDirectory.appendingPathComponent("history.json", isDirectory: false)
        databaseFileURL = llhDirectory.appendingPathComponent("history.sqlite", isDirectory: false)
    }

    init(
        applicationSupportDirectory: URL,
        jsonFileName: String = "history.json",
        databaseFileName: String = "history.sqlite"
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
        jsonFileURL = applicationSupportDirectory.appendingPathComponent(jsonFileName, isDirectory: false)
        databaseFileURL = applicationSupportDirectory.appendingPathComponent(databaseFileName, isDirectory: false)
    }

    func ensureDirectoryExists(fileManager: FileManager = .default) throws {
        if !fileManager.fileExists(atPath: applicationSupportDirectory.path) {
            try fileManager.createDirectory(
                at: applicationSupportDirectory,
                withIntermediateDirectories: true
            )
        }
    }
}
