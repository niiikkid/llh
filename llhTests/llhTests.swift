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

    @Test
    func learningProfile_deleteEntry_removesSelectedAndRepointsSelection() {
        let first = CapturedTextEntry(text: "First")
        let second = CapturedTextEntry(text: "Second")
        var profile = LearningProfile(
            name: "English",
            history: [first, second],
            selectedEntryID: first.id
        )

        let removed = profile.deleteEntry(with: first.id)

        #expect(removed == true)
        #expect(profile.history.count == 1)
        #expect(profile.history.first?.id == second.id)
        #expect(profile.selectedEntryID == second.id)
    }

    @Test
    @MainActor
    func openAISettingsStore_persistsSelectedModelID() {
        let suiteName = "llh.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var store = OpenAISettingsStore(
            userDefaults: defaults,
            selectedModelKey: "selected.model.test"
        )

        #expect(store.selectedModelID == nil)
        store.selectedModelID = "gpt-4.1-mini"
        #expect(store.selectedModelID == "gpt-4.1-mini")

        #expect(store.selectedLearningLanguageRawValue == LearningLanguage.english.rawValue)
        store.selectedLearningLanguageRawValue = LearningLanguage.chinese.rawValue
        #expect(store.selectedLearningLanguageRawValue == LearningLanguage.chinese.rawValue)
    }

    @Test
    func capturedTextEntry_codableIncludesFormattingFields() throws {
        let entry = CapturedTextEntry(
            text: "ni hao 你好",
            formattedText: "你好",
            formattingStatus: .succeeded
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CapturedTextEntry.self, from: data)

        #expect(decoded.text == "ni hao 你好")
        #expect(decoded.formattedText == "你好")
        #expect(decoded.formattingStatus == .succeeded)
    }
}
