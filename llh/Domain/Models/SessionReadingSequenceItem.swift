//
//  SessionReadingSequenceItem.swift
//  llh
//

import Foundation

struct SessionReadingSequenceItem: Identifiable, Equatable {
    let id: CapturedTextEntry.ID
    let sourceLine: String
    let translationLine: String
    let wordStudy: WordStudyPayload?
    let grammarStudy: GrammarExplanationPayload?

    /// Плейсхолдер пустого оригинала в режиме «вся сессия» (совпадает с подписью в интерфейсе).
    static let missingSourcePlaceholder = "—"
    /// Плейсхолдер, если форматирования ещё нет (совпадает с подписью в интерфейсе).
    static let missingTranslationPlaceholder = "Перевод пока недоступен"

    init(
        id: CapturedTextEntry.ID,
        sourceLine: String,
        translationLine: String,
        wordStudy: WordStudyPayload? = nil,
        grammarStudy: GrammarExplanationPayload? = nil
    ) {
        self.id = id
        self.sourceLine = sourceLine
        self.translationLine = translationLine
        self.wordStudy = wordStudy
        self.grammarStudy = grammarStudy
    }

    init(entry: CapturedTextEntry, learningLanguage: LearningLanguage) {
        self.init(
            id: entry.id,
            sourceLine: entry.sessionReadingSourceLine(learningLanguage: learningLanguage),
            translationLine: entry.sessionReadingTranslationLine(),
            wordStudy: Self.availableWordStudy(from: entry.studyMaterials),
            grammarStudy: Self.availableGrammarStudy(from: entry.studyMaterials)
        )
    }

    var hasExpandableDetails: Bool {
        wordStudy != nil || grammarStudy != nil
    }

    /// Строка оригинала для отображения и копирования.
    var displaySourceLine: String {
        sourceLine.isEmpty ? Self.missingSourcePlaceholder : sourceLine
    }

    /// Строка перевода для отображения и копирования.
    var displayTranslationLine: String {
        translationLine.isEmpty ? Self.missingTranslationPlaceholder : translationLine
    }

    static func availableWordStudy(from materials: StudyMaterials) -> WordStudyPayload? {
        guard materials.wordsStatus == .succeeded,
              let words = materials.words,
              words.hasContent
        else { return nil }
        return words
    }

    static func availableGrammarStudy(from materials: StudyMaterials) -> GrammarExplanationPayload? {
        guard materials.grammarStatus == .succeeded,
              let grammar = materials.grammar,
              grammar.hasContent
        else { return nil }
        return grammar
    }
}
