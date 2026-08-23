//
//  TranslationChatModels.swift
//  llh
//

import Foundation

struct TranslationChatContext: Equatable, Sendable {
    let learningLanguage: LearningLanguage
    let cleanedText: String
    let pinyinText: String
    let russianTranslation: String
    let wordEntries: [WordStudyEntry]

    init(
        formattedText: StructuredFormattedText,
        words: WordStudyPayload? = nil,
        learningLanguage: LearningLanguage = .auto
    ) {
        self.learningLanguage = learningLanguage
        cleanedText = formattedText.cleanedText
        pinyinText = formattedText.pinyinText
        russianTranslation = formattedText.russianTranslation
        wordEntries = words?.entries ?? []
    }

    init(
        learningLanguage: LearningLanguage = .auto,
        cleanedText: String,
        pinyinText: String,
        russianTranslation: String,
        wordEntries: [WordStudyEntry]
    ) {
        self.learningLanguage = learningLanguage
        self.cleanedText = cleanedText
        self.pinyinText = pinyinText
        self.russianTranslation = russianTranslation
        self.wordEntries = wordEntries
    }

    /// Chinese sessions, and auto-detect with pinyin, must never get hanzi in chat replies.
    var forbidsHanziInReplies: Bool {
        switch learningLanguage {
        case .chinese:
            return true
        case .auto:
            return !pinyinText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .english, .spanish:
            return false
        }
    }
}

struct TranslationChatMessage: Equatable, Identifiable, Sendable {
    enum Role: String, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}
