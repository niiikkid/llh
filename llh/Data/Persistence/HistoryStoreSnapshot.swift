//
//  HistoryStoreSnapshot.swift
//  llh
//

import Foundation

/// JSON on-disk shape for `history.json`. Not a domain entity.
struct HistoryStoreSnapshot: Codable {
    var profiles: [LearningProfile]
    var selectedProfileID: LearningProfile.ID?
}
