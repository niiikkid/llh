//
//  ManageProfilesUseCase.swift
//  llh
//

import Foundation

enum ManageProfilesDeleteOutcome: Equatable {
    case deleted(removedName: String)
    case cannotDeleteDefaultProfile
    case noSelectedProfile
}

@MainActor
struct ManageProfilesUseCase {
    private let manageHistoryUseCase: ManageHistoryUseCase

    init(manageHistoryUseCase: ManageHistoryUseCase) {
        self.manageHistoryUseCase = manageHistoryUseCase
    }

    static func normalizedProfileName(from rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Новый профиль" : trimmed
    }

    func canDeleteSelectedProfile(state: HistorySessionState) -> Bool {
        guard let profileIndex = state.selectedProfileIndex else { return false }
        return !state.profiles[profileIndex].isDefaultProfile
    }

    @discardableResult
    func createProfile(
        state: inout HistorySessionState,
        named rawName: String,
        learningLanguage: LearningLanguage
    ) -> LearningProfile {
        let profile = LearningProfile(
            name: Self.normalizedProfileName(from: rawName),
            learningLanguage: learningLanguage
        )
        state.profiles.insert(profile, at: 0)
        state.selectedProfileID = profile.id
        manageHistoryUseCase.resolveEntrySelectionForSelectedProfile(state: &state)
        return profile
    }

    func selectProfile(state: inout HistorySessionState, profileID: LearningProfile.ID?) {
        state.selectedProfileID = profileID
        if state.selectedProfileIndex != nil {
            manageHistoryUseCase.resolveEntrySelectionForSelectedProfile(state: &state)
        } else {
            state.selectedEntryID = nil
        }
    }

    func deleteSelectedProfile(state: inout HistorySessionState) -> ManageProfilesDeleteOutcome {
        guard let profileIndex = state.selectedProfileIndex else {
            return .noSelectedProfile
        }
        guard !state.profiles[profileIndex].isDefaultProfile else {
            return .cannotDeleteDefaultProfile
        }
        let removedName = state.profiles[profileIndex].name
        state.profiles.remove(at: profileIndex)
        state.selectedProfileID = state.profiles.first?.id
        if state.selectedProfileIndex != nil {
            manageHistoryUseCase.resolveEntrySelectionForSelectedProfile(state: &state)
        } else {
            state.selectedEntryID = nil
        }
        return .deleted(removedName: removedName)
    }
}
