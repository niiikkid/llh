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
    /// After formatting succeeds, load word study automatically for new results in this session.
    var automaticallyLoadWords: Bool
    /// After formatting succeeds, load grammar study automatically for new results in this session.
    var automaticallyLoadGrammar: Bool
    /// When compact overlay is used, show word study below the translation and keep the overlay open until dismissed.
    var showWordsInCompactOverlay: Bool

    init(
        id: UUID = UUID(),
        name: String,
        learningLanguage: LearningLanguage = .english,
        kind: LearningProfileKind = .custom,
        createdAt: Date = Date(),
        history: [CapturedTextEntry] = [],
        selectedEntryID: CapturedTextEntry.ID? = nil,
        automaticallyLoadWords: Bool = false,
        automaticallyLoadGrammar: Bool = false,
        showWordsInCompactOverlay: Bool = false
    ) {
        self.id = id
        self.name = name
        self.learningLanguage = learningLanguage
        self.kind = kind
        self.createdAt = createdAt
        self.history = history
        self.selectedEntryID = selectedEntryID
        self.automaticallyLoadWords = automaticallyLoadWords
        self.automaticallyLoadGrammar = automaticallyLoadGrammar
        self.showWordsInCompactOverlay = showWordsInCompactOverlay
    }

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        history: [CapturedTextEntry] = [],
        selectedEntryID: CapturedTextEntry.ID? = nil,
        automaticallyLoadWords: Bool = false,
        automaticallyLoadGrammar: Bool = false,
        showWordsInCompactOverlay: Bool = false
    ) {
        self.init(
            id: id,
            name: name,
            learningLanguage: .english,
            kind: .custom,
            createdAt: createdAt,
            history: history,
            selectedEntryID: selectedEntryID,
            automaticallyLoadWords: automaticallyLoadWords,
            automaticallyLoadGrammar: automaticallyLoadGrammar,
            showWordsInCompactOverlay: showWordsInCompactOverlay
        )
    }

    static func defaultProfile(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        history: [CapturedTextEntry] = [],
        selectedEntryID: CapturedTextEntry.ID? = nil,
        automaticallyLoadWords: Bool = false,
        automaticallyLoadGrammar: Bool = false,
        showWordsInCompactOverlay: Bool = false
    ) -> LearningProfile {
        LearningProfile(
            id: id,
            name: "Default",
            learningLanguage: .auto,
            kind: .default,
            createdAt: createdAt,
            history: history,
            selectedEntryID: selectedEntryID,
            automaticallyLoadWords: automaticallyLoadWords,
            automaticallyLoadGrammar: automaticallyLoadGrammar,
            showWordsInCompactOverlay: showWordsInCompactOverlay
        )
    }

    var isDefaultProfile: Bool {
        kind == .default
    }

    /// User-visible session name; legacy persisted `"Default"` stays in storage.
    var displayName: String {
        if isDefaultProfile || name == "Default" {
            return "По умолчанию"
        }
        return name
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case learningLanguage
        case kind
        case createdAt
        case history
        case selectedEntryID
        case automaticallyLoadWords
        case automaticallyLoadGrammar
        case showWordsInCompactOverlay
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
        automaticallyLoadWords = try container.decodeIfPresent(Bool.self, forKey: .automaticallyLoadWords) ?? false
        automaticallyLoadGrammar = try container.decodeIfPresent(Bool.self, forKey: .automaticallyLoadGrammar) ?? false
        showWordsInCompactOverlay = try container.decodeIfPresent(Bool.self, forKey: .showWordsInCompactOverlay) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(learningLanguage, forKey: .learningLanguage)
        try container.encode(kind, forKey: .kind)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(history, forKey: .history)
        try container.encodeIfPresent(selectedEntryID, forKey: .selectedEntryID)
        try container.encode(automaticallyLoadWords, forKey: .automaticallyLoadWords)
        try container.encode(automaticallyLoadGrammar, forKey: .automaticallyLoadGrammar)
        try container.encode(showWordsInCompactOverlay, forKey: .showWordsInCompactOverlay)
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
