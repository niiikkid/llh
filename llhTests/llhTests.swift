//
//  llhTests.swift
//  llhTests
//
//  Created by itsme on 06.04.2026.
//

import Testing
import Foundation
@testable import llh

struct llhTests {
    @Test
    func normalizeRecognizedLines_removesNoiseAndKeepsLineBreaks() {
        let input = [
            "  Hello world  ",
            "",
            "   ",
            "\nSecond line\n",
        ]

        let output = TextFormatter.normalizeRecognizedLines(input)
        #expect(output == "Hello world\nSecond line")
    }

    @Test
    func capturedTextEntry_buildsCompactTitleAndPreview() {
        let entry = CapturedTextEntry(
            text: """
                  First line title
                  Here goes another sentence for preview formatting.
                  """
        )

        #expect(entry.title == "First line title")
        #expect(entry.preview.contains("First line title Here goes another sentence"))
    }

    @Test
    func historyPersistenceService_savesAndLoadsHistory() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = folderURL.appendingPathComponent("history.json", isDirectory: false)
        let service = HistoryPersistenceService(fileURL: fileURL)
        let sourceProfile = LearningProfile(
            name: "Spanish",
            history: [
                CapturedTextEntry(text: "Hello"),
                CapturedTextEntry(text: "World")
            ],
            selectedEntryID: nil
        )
        let snapshot = HistoryStoreSnapshot(
            profiles: [sourceProfile],
            selectedProfileID: sourceProfile.id
        )

        try service.saveStore(snapshot)
        let loaded = try service.loadStore()

        #expect(loaded.profiles.count == 1)
        #expect(loaded.selectedProfileID == sourceProfile.id)
        #expect(loaded.profiles[0].name == "Spanish")
        #expect(loaded.profiles[0].history.map(\.text) == ["Hello", "World"])
        #expect(loaded.profiles[0].history[0].id == sourceProfile.history[0].id)
    }
}
