//
//  ManageHistoryUseCase.swift
//  llh
//

import Foundation

@MainActor
struct ManageHistoryUseCase {
    private let historyRepository: HistoryRepository

    init(historyRepository: HistoryRepository) {
        self.historyRepository = historyRepository
    }

    func loadSession() throws -> HistorySessionState {
        let store = try historyRepository.loadStore()
        return Self.normalizeLoadedStore(store)
    }

    func saveSession(_ state: HistorySessionState) throws {
        let snapshot = HistoryStoreSnapshot(
            profiles: state.profiles,
            selectedProfileID: state.selectedProfileID
        )
        try historyRepository.saveStore(snapshot)
    }

    /// Aligns `selectedEntryID` with the active profile's persisted selection or first entry.
    @discardableResult
    func resolveEntrySelectionForSelectedProfile(state: inout HistorySessionState) -> CapturedTextEntry.ID? {
        guard let profileIndex = state.selectedProfileIndex else {
            state.selectedEntryID = nil
            return nil
        }

        if let persistedSelection = state.profiles[profileIndex].selectedEntryID,
           state.profiles[profileIndex].history.contains(where: { $0.id == persistedSelection }) {
            state.selectedEntryID = persistedSelection
        } else {
            state.selectedEntryID = state.profiles[profileIndex].history.first?.id
            state.profiles[profileIndex].selectedEntryID = state.selectedEntryID
        }
        return state.selectedEntryID
    }

    func selectEntry(state: inout HistorySessionState, entryID: CapturedTextEntry.ID?) {
        state.selectedEntryID = entryID
        if let profileIndex = state.selectedProfileIndex {
            state.profiles[profileIndex].selectedEntryID = entryID
        }
    }

    @discardableResult
    func deleteEntry(state: inout HistorySessionState, entryID: CapturedTextEntry.ID) -> Bool {
        guard let profileIndex = state.selectedProfileIndex else { return false }
        guard state.profiles[profileIndex].deleteEntry(with: entryID) else { return false }
        state.selectedEntryID = state.profiles[profileIndex].selectedEntryID
        return true
    }

    func insertEntry(
        state: inout HistorySessionState,
        profileIndex: Int,
        entry: CapturedTextEntry
    ) {
        state.profiles[profileIndex].history.insert(entry, at: 0)
        state.profiles[profileIndex].selectedEntryID = entry.id
        state.selectedEntryID = entry.id
    }

    @discardableResult
    func updateSelectedEntryText(state: inout HistorySessionState, newText: String) -> Bool {
        guard let profileIndex = state.selectedProfileIndex,
              let entryIndex = state.selectedEntryIndex else {
            return false
        }
        state.profiles[profileIndex].history[entryIndex].text = newText
        state.profiles[profileIndex].history[entryIndex].formattedText = nil
        state.profiles[profileIndex].history[entryIndex].formattingStatus = .notRequested
        state.profiles[profileIndex].history[entryIndex].studyMaterials = StudyMaterials()
        state.profiles[profileIndex].selectedEntryID = state.selectedEntryID
        return true
    }

    @discardableResult
    func mutateEntry(
        state: inout HistorySessionState,
        profileID: LearningProfile.ID,
        entryID: CapturedTextEntry.ID,
        _ body: (inout CapturedTextEntry) -> Void
    ) -> Bool {
        guard let indices = state.entryIndex(profileID: profileID, entryID: entryID) else {
            return false
        }
        body(&state.profiles[indices.profileIndex].history[indices.entryIndex])
        return true
    }

    static func normalizeLoadedStore(_ store: HistoryStoreSnapshot) -> HistorySessionState {
        var profiles = store.profiles.map(HistoryEntryLoadRepair.repairProfile)
        if !profiles.contains(where: \.isDefaultProfile) {
            profiles.insert(.defaultProfile(), at: 0)
        }
        if let defaultIndex = profiles.firstIndex(where: \.isDefaultProfile), defaultIndex != 0 {
            let defaultProfile = profiles.remove(at: defaultIndex)
            profiles.insert(defaultProfile, at: 0)
        }

        var selectedProfileID = store.selectedProfileID
        if selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) {
            selectedProfileID = profiles.first?.id
        }

        return HistorySessionState(
            profiles: profiles,
            selectedProfileID: selectedProfileID,
            selectedEntryID: nil
        )
    }
}
