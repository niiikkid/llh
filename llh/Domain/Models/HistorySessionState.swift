//
//  HistorySessionState.swift
//  llh
//

import Foundation

/// In-memory history session: profiles, active profile, and current entry selection.
struct HistorySessionState: Equatable {
    var profiles: [LearningProfile]
    var selectedProfileID: LearningProfile.ID?
    var selectedEntryID: CapturedTextEntry.ID?

    var selectedProfileIndex: Int? {
        guard let selectedProfileID else { return nil }
        return profiles.firstIndex(where: { $0.id == selectedProfileID })
    }

    var selectedEntryIndex: Int? {
        guard let selectedEntryID, let selectedProfileIndex else { return nil }
        return profiles[selectedProfileIndex].history.firstIndex(where: { $0.id == selectedEntryID })
    }

    func profileIndex(for profileID: LearningProfile.ID) -> Int? {
        profiles.firstIndex(where: { $0.id == profileID })
    }

    func entryIndex(profileID: LearningProfile.ID, entryID: CapturedTextEntry.ID) -> (profileIndex: Int, entryIndex: Int)? {
        guard let profileIndex = profileIndex(for: profileID),
              let entryIndex = profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return nil
        }
        return (profileIndex, entryIndex)
    }
}
