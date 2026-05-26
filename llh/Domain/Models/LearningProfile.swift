//
//  LearningProfile.swift
//  llh
//

import Foundation

enum LearningProfileKind: String, Codable {
    case custom
    case `default`
}

struct LearningProfile: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var learningLanguage: LearningLanguage
    var kind: LearningProfileKind
    let createdAt: Date
    var history: [CapturedTextEntry]
    var selectedEntryID: CapturedTextEntry.ID?

    init(
        id: UUID = UUID(),
        name: String,
        learningLanguage: LearningLanguage = .english,
        kind: LearningProfileKind = .custom,
        createdAt: Date = Date(),
        history: [CapturedTextEntry] = [],
        selectedEntryID: CapturedTextEntry.ID? = nil
    ) {
        self.id = id
        self.name = name
        self.learningLanguage = learningLanguage
        self.kind = kind
        self.createdAt = createdAt
        self.history = history
        self.selectedEntryID = selectedEntryID
    }

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        history: [CapturedTextEntry] = [],
        selectedEntryID: CapturedTextEntry.ID? = nil
    ) {
        self.init(
            id: id,
            name: name,
            learningLanguage: .english,
            kind: .custom,
            createdAt: createdAt,
            history: history,
            selectedEntryID: selectedEntryID
        )
    }

    static func defaultProfile(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        history: [CapturedTextEntry] = [],
        selectedEntryID: CapturedTextEntry.ID? = nil
    ) -> LearningProfile {
        LearningProfile(
            id: id,
            name: "Default",
            learningLanguage: .auto,
            kind: .default,
            createdAt: createdAt,
            history: history,
            selectedEntryID: selectedEntryID
        )
    }

    var isDefaultProfile: Bool {
        kind == .default
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case learningLanguage
        case kind
        case createdAt
        case history
        case selectedEntryID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        learningLanguage = try container.decodeIfPresent(LearningLanguage.self, forKey: .learningLanguage) ?? .english
        kind = try container.decodeIfPresent(LearningProfileKind.self, forKey: .kind) ?? .custom
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        history = try container.decodeIfPresent([CapturedTextEntry].self, forKey: .history) ?? []
        selectedEntryID = try container.decodeIfPresent(CapturedTextEntry.ID.self, forKey: .selectedEntryID)
    }

    mutating func deleteEntry(with id: CapturedTextEntry.ID) -> Bool {
        guard let index = history.firstIndex(where: { $0.id == id }) else {
            return false
        }
        history.remove(at: index)
        selectedEntryID = history.first?.id
        return true
    }
}
