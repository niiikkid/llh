//
//  TranslationChatModels.swift
//  llh
//

import Foundation

struct TranslationChatContext: Equatable, Sendable {
    let cleanedText: String
    let pinyinText: String
    let russianTranslation: String
    let wordEntries: [WordStudyEntry]

    init(
        formattedText: StructuredFormattedText,
        words: WordStudyPayload? = nil
    ) {
        cleanedText = formattedText.cleanedText
        pinyinText = formattedText.pinyinText
        russianTranslation = formattedText.russianTranslation
        wordEntries = words?.entries ?? []
    }

    init(
        cleanedText: String,
        pinyinText: String,
        russianTranslation: String,
        wordEntries: [WordStudyEntry]
    ) {
        self.cleanedText = cleanedText
        self.pinyinText = pinyinText
        self.russianTranslation = russianTranslation
        self.wordEntries = wordEntries
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
