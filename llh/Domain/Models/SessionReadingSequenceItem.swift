//
//  SessionReadingSequenceItem.swift
//  llh
//

import Foundation

struct SessionReadingSequenceItem: Identifiable, Equatable {
    let id: CapturedTextEntry.ID
    let sourceLine: String
    let translationLine: String

    /// Плейсхолдер пустого оригинала в режиме «вся сессия» (совпадает с подписью в интерфейсе).
    static let missingSourcePlaceholder = "—"
    /// Плейсхолдер, если форматирования ещё нет (совпадает с подписью в интерфейсе).
    static let missingTranslationPlaceholder = "Перевод пока недоступен"

    /// Строка оригинала для отображения и копирования.
    var displaySourceLine: String {
        sourceLine.isEmpty ? Self.missingSourcePlaceholder : sourceLine
    }

    /// Строка перевода для отображения и копирования.
    var displayTranslationLine: String {
        translationLine.isEmpty ? Self.missingTranslationPlaceholder : translationLine
    }
}
