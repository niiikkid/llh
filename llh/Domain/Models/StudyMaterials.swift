//
//  StudyMaterials.swift
//  llh
//

import Foundation

struct StudyListItem: Equatable, Codable {
    let pinyinText: String
    let russianTranslation: String
}

struct CharacterMeaning: Equatable, Codable {
    let pinyinText: String
    let russianTranslation: String
}

struct WordStudyEntry: Equatable, Codable {
    let termPinyin: String
    let termTranslation: String
    /// Как произнести слово русскоговорящему: кириллическая подсказка (например для испанского).
    let russianPronunciationGuide: String
    let characterBreakdown: [CharacterMeaning]

    enum CodingKeys: String, CodingKey {
        case termPinyin
        case termTranslation
        case russianPronunciationGuide
        case characterBreakdown
    }

    init(
        termPinyin: String,
        termTranslation: String,
        russianPronunciationGuide: String = "",
        characterBreakdown: [CharacterMeaning]
    ) {
        self.termPinyin = termPinyin
        self.termTranslation = termTranslation
        self.russianPronunciationGuide = russianPronunciationGuide
        self.characterBreakdown = characterBreakdown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        termPinyin = try container.decode(String.self, forKey: .termPinyin)
        termTranslation = try container.decode(String.self, forKey: .termTranslation)
        russianPronunciationGuide = try container.decodeIfPresent(String.self, forKey: .russianPronunciationGuide) ?? ""
        characterBreakdown = try container.decode([CharacterMeaning].self, forKey: .characterBreakdown)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(termPinyin, forKey: .termPinyin)
        try container.encode(termTranslation, forKey: .termTranslation)
        try container.encode(russianPronunciationGuide, forKey: .russianPronunciationGuide)
        try container.encode(characterBreakdown, forKey: .characterBreakdown)
    }
}

struct WordStudyPayload: Equatable, Codable {
    let entries: [WordStudyEntry]

    var hasContent: Bool {
        !entries.isEmpty
    }
}

struct PhraseStudyPayload: Equatable, Codable {
    let entries: [StudyListItem]

    var hasContent: Bool {
        !entries.isEmpty
    }
}

struct GrammarExample: Equatable, Codable {
    let pinyinText: String
    let russianTranslation: String
}

struct GrammarStructure: Equatable, Codable {
    let title: String
    let explanation: String
    let usageNotes: String
    let examples: [GrammarExample]

    var hasVisibleContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !usageNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !examples.isEmpty
    }
}

struct GrammarExplanationPayload: Equatable, Codable {
    let structures: [GrammarStructure]

    var hasContent: Bool {
        structures.contains(where: \.hasVisibleContent)
    }
}

struct StudyAssistantData: Equatable, Codable {
    let words: [StudyListItem]
    let phrases: [StudyListItem]
    let grammar: LegacyGrammarExplanation

    var hasContent: Bool {
        !words.isEmpty || !phrases.isEmpty || !grammar.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct LegacyGrammarExplanation: Equatable, Codable {
    let summary: String
    let examples: [GrammarExample]
}

struct StudyMaterials: Equatable, Codable {
    var words: WordStudyPayload?
    var wordsStatus: FormattingStatus
    var phrases: PhraseStudyPayload?
    var phrasesStatus: FormattingStatus
    var grammar: GrammarExplanationPayload?
    var grammarStatus: FormattingStatus

    init(
        words: WordStudyPayload? = nil,
        wordsStatus: FormattingStatus = .notRequested,
        phrases: PhraseStudyPayload? = nil,
        phrasesStatus: FormattingStatus = .notRequested,
        grammar: GrammarExplanationPayload? = nil,
        grammarStatus: FormattingStatus = .notRequested
    ) {
        self.words = words
        self.wordsStatus = wordsStatus
        self.phrases = phrases
        self.phrasesStatus = phrasesStatus
        self.grammar = grammar
        self.grammarStatus = grammarStatus
    }
}
