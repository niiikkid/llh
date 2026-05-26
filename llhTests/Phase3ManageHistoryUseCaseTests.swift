//
//  Phase3ManageHistoryUseCaseTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

@MainActor
private func makeUseCase(fileURL: URL) -> ManageHistoryUseCase {
    let persistence = HistoryPersistenceService(fileURL: fileURL)
    return ManageHistoryUseCase(historyRepository: JSONHistoryRepository(persistence: persistence))
}

@MainActor
private func temporaryHistoryFileURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("history.json", isDirectory: false)
}

struct Phase3ManageHistoryUseCaseTests {
    @Test
    @MainActor
    func normalizeLoadedStore_insertsDefaultProfileWhenMissing() {
        let custom = LearningProfile(name: "Custom", learningLanguage: .english)
        let store = HistoryStoreSnapshot(profiles: [custom], selectedProfileID: custom.id)

        let state = ManageHistoryUseCase.normalizeLoadedStore(store)

        #expect(state.profiles.count == 2)
        #expect(state.profiles[0].isDefaultProfile)
        #expect(state.profiles[1].id == custom.id)
    }

    @Test
    @MainActor
    func normalizeLoadedStore_movesDefaultProfileToIndexZero() {
        let custom = LearningProfile(name: "Custom", learningLanguage: .english)
        let defaultProfile = LearningProfile.defaultProfile()
        let store = HistoryStoreSnapshot(
            profiles: [custom, defaultProfile],
            selectedProfileID: custom.id
        )

        let state = ManageHistoryUseCase.normalizeLoadedStore(store)

        #expect(state.profiles[0].isDefaultProfile)
        #expect(state.profiles[1].id == custom.id)
    }

    @Test
    @MainActor
    func normalizeLoadedStore_repairsInterruptedProcessingEntry() {
        var entry = CapturedTextEntry(text: "你好")
        entry.formattingStatus = .processing
        let profile = LearningProfile(name: "P", history: [entry])
        let store = HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)

        let state = ManageHistoryUseCase.normalizeLoadedStore(store)

        #expect(state.profiles[0].history[0].formattingStatus == .failed)
    }

    @Test
    @MainActor
    func loadSession_fallsBackToFirstProfileWhenSelectionMissing() throws {
        let fileURL = temporaryHistoryFileURL()
        let useCase = makeUseCase(fileURL: fileURL)
        let profile = LearningProfile.defaultProfile()
        try useCase.saveSession(
            HistorySessionState(profiles: [profile], selectedProfileID: nil, selectedEntryID: nil)
        )

        let loaded = try useCase.loadSession()

        #expect(loaded.selectedProfileID == profile.id)
    }

    @Test
    @MainActor
    func deleteEntry_updatesSelectionToNextEntry() {
        let first = CapturedTextEntry(text: "a")
        let second = CapturedTextEntry(text: "b")
        let profile = LearningProfile(
            name: "P",
            history: [first, second],
            selectedEntryID: first.id
        )
        var state = HistorySessionState(
            profiles: [profile],
            selectedProfileID: profile.id,
            selectedEntryID: first.id
        )
        let useCase = ManageHistoryUseCase(historyRepository: JSONHistoryRepository())

        let deleted = useCase.deleteEntry(state: &state, entryID: first.id)

        #expect(deleted)
        #expect(state.profiles[0].history.count == 1)
        #expect(state.selectedEntryID == second.id)
        #expect(state.profiles[0].selectedEntryID == second.id)
    }

    @Test
    @MainActor
    func insertEntry_prependsAndSelectsNewEntry() {
        let existing = CapturedTextEntry(text: "old")
        let profile = LearningProfile(name: "P", history: [existing])
        var state = HistorySessionState(
            profiles: [profile],
            selectedProfileID: profile.id,
            selectedEntryID: existing.id
        )
        let useCase = ManageHistoryUseCase(historyRepository: JSONHistoryRepository())
        let newEntry = CapturedTextEntry(text: "new")

        useCase.insertEntry(state: &state, profileIndex: 0, entry: newEntry)

        #expect(state.profiles[0].history.map(\.text) == ["new", "old"])
        #expect(state.selectedEntryID == newEntry.id)
    }

    @Test
    @MainActor
    func resolveEntrySelection_usesFirstEntryWhenPersistedSelectionMissing() {
        let only = CapturedTextEntry(text: "only")
        var profile = LearningProfile(name: "P", history: [only], selectedEntryID: UUID())
        let profileID = profile.id
        var state = HistorySessionState(
            profiles: [profile],
            selectedProfileID: profileID,
            selectedEntryID: nil
        )
        let useCase = ManageHistoryUseCase(historyRepository: JSONHistoryRepository())

        let resolved = useCase.resolveEntrySelectionForSelectedProfile(state: &state)

        #expect(resolved == only.id)
        #expect(state.profiles[0].selectedEntryID == only.id)
    }

    @Test
    @MainActor
    func updateSelectedEntryText_clearsFormattingAndStudy() {
        var entry = CapturedTextEntry(text: "old")
        entry.formattedText = StructuredFormattedText(
            cleanedText: "x",
            pinyinText: nil,
            russianTranslation: "y"
        )
        entry.formattingStatus = .succeeded
        entry.studyMaterials.wordsStatus = .succeeded
        let profile = LearningProfile(name: "P", history: [entry], selectedEntryID: entry.id)
        var state = HistorySessionState(
            profiles: [profile],
            selectedProfileID: profile.id,
            selectedEntryID: entry.id
        )
        let useCase = ManageHistoryUseCase(historyRepository: JSONHistoryRepository())

        let updated = useCase.updateSelectedEntryText(state: &state, newText: "new")

        #expect(updated)
        #expect(state.profiles[0].history[0].text == "new")
        #expect(state.profiles[0].history[0].formattedText == nil)
        #expect(state.profiles[0].history[0].formattingStatus == .notRequested)
        #expect(state.profiles[0].history[0].studyMaterials == StudyMaterials())
    }

    @Test
    @MainActor
    func saveSession_roundtripsThroughRepository() throws {
        let fileURL = temporaryHistoryFileURL()
        let useCase = makeUseCase(fileURL: fileURL)
        let entry = CapturedTextEntry(text: "persisted")
        let profile = LearningProfile(name: "P", history: [entry], selectedEntryID: entry.id)
        var state = HistorySessionState(
            profiles: [profile],
            selectedProfileID: profile.id,
            selectedEntryID: entry.id
        )

        try useCase.saveSession(state)
        var loaded = try useCase.loadSession()
        useCase.resolveEntrySelectionForSelectedProfile(state: &loaded)

        #expect(loaded.profiles[0].history.first?.text == "persisted")
        #expect(loaded.selectedProfileID == profile.id)
        #expect(loaded.selectedEntryID == entry.id)
    }

    @Test
    @MainActor
    func mutateEntry_updatesEntryInNamedProfile() {
        let entry = CapturedTextEntry(text: "x")
        let profile = LearningProfile(name: "P", history: [entry])
        var state = HistorySessionState(
            profiles: [profile],
            selectedProfileID: profile.id,
            selectedEntryID: entry.id
        )
        let useCase = ManageHistoryUseCase(historyRepository: JSONHistoryRepository())

        let changed = useCase.mutateEntry(state: &state, profileID: profile.id, entryID: entry.id) { entry in
            entry.formattingStatus = .processing
        }

        #expect(changed)
        #expect(state.profiles[0].history[0].formattingStatus == .processing)
    }
}
