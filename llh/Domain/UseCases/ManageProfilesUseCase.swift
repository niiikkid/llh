//
//  ManageProfilesUseCase.swift
//  llh
//

import Foundation

enum ManageProfilesDeleteOutcome: Equatable {
    case deleted(removedName: String)
    case cannotDeleteDefaultProfile
    case noSelectedProfile
    case profileNotFound
}

enum ManageProfilesRenameOutcome: Equatable {
    case renamed(displayName: String)
    case profileNotFound
}

enum ManageProfilesAutomationOutcome: Equatable {
    case updated
    case profileNotFound
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

    func canDeleteProfile(state: HistorySessionState, profileID: LearningProfile.ID) -> Bool {
        guard let profileIndex = state.profiles.firstIndex(where: { $0.id == profileID }) else {
            return false
        }
        return !state.profiles[profileIndex].isDefaultProfile
    }

    func canDeleteSelectedProfile(state: HistorySessionState) -> Bool {
        guard let profileID = state.selectedProfileID else { return false }
        return canDeleteProfile(state: state, profileID: profileID)
    }

    @discardableResult
    func createProfile(
        state: inout HistorySessionState,
        named rawName: String,
        learningLanguage: LearningLanguage,
        automaticallyLoadWords: Bool = false,
        automaticallyLoadGrammar: Bool = false,
        showWordsInCompactOverlay: Bool = false
    ) -> LearningProfile {
        let profile = LearningProfile(
            name: Self.normalizedProfileName(from: rawName),
            learningLanguage: learningLanguage,
            automaticallyLoadWords: automaticallyLoadWords,
            automaticallyLoadGrammar: automaticallyLoadGrammar,
            showWordsInCompactOverlay: showWordsInCompactOverlay
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

    func updateSessionAutomation(
        state: inout HistorySessionState,
        profileID: LearningProfile.ID,
        automaticallyLoadWords: Bool,
        automaticallyLoadGrammar: Bool,
        showWordsInCompactOverlay: Bool
    ) -> ManageProfilesAutomationOutcome {
        guard let profileIndex = state.profiles.firstIndex(where: { $0.id == profileID }) else {
            return .profileNotFound
        }
        state.profiles[profileIndex].automaticallyLoadWords = automaticallyLoadWords
        state.profiles[profileIndex].automaticallyLoadGrammar = automaticallyLoadGrammar
        state.profiles[profileIndex].showWordsInCompactOverlay = showWordsInCompactOverlay
        return .updated
    }

    func renameProfile(
        state: inout HistorySessionState,
        profileID: LearningProfile.ID,
        named rawName: String
    ) -> ManageProfilesRenameOutcome {
        guard let profileIndex = state.profiles.firstIndex(where: { $0.id == profileID }) else {
            return .profileNotFound
        }
        state.profiles[profileIndex].name = Self.normalizedProfileName(from: rawName)
        return .renamed(displayName: state.profiles[profileIndex].displayName)
    }

    func deleteProfile(
        state: inout HistorySessionState,
        profileID: LearningProfile.ID
    ) -> ManageProfilesDeleteOutcome {
        guard let profileIndex = state.profiles.firstIndex(where: { $0.id == profileID }) else {
            return .profileNotFound
        }
        guard !state.profiles[profileIndex].isDefaultProfile else {
            return .cannotDeleteDefaultProfile
        }
        let removedName = state.profiles[profileIndex].name
        let wasSelected = state.selectedProfileID == profileID
        state.profiles.remove(at: profileIndex)
        if wasSelected {
            state.selectedProfileID = state.profiles.first?.id
            if state.selectedProfileIndex != nil {
                manageHistoryUseCase.resolveEntrySelectionForSelectedProfile(state: &state)
            } else {
                state.selectedEntryID = nil
            }
        }
        return .deleted(removedName: removedName)
    }

    func deleteSelectedProfile(state: inout HistorySessionState) -> ManageProfilesDeleteOutcome {
        guard let profileID = state.selectedProfileID else {
            return .noSelectedProfile
        }
        return deleteProfile(state: &state, profileID: profileID)
    }
}
