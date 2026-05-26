//
//  StructuredFormattedText.swift
//  llh
//

import Foundation

struct StructuredFormattedText: Equatable, Codable {
    let cleanedText: String
    let pinyinText: String
    let russianTranslation: String

    var hasContent: Bool {
        !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Текст источника для строки списка переводов: для китайской сессии и авто с непустым пиньинем — пиньинь, иначе очищенный исходник.
    func sessionListSourceDisplay(learningLanguage: LearningLanguage) -> String {
        let trimmedCleaned = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPinyin = pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch learningLanguage {
        case .chinese:
            if !trimmedPinyin.isEmpty {
                return pinyinText
            }
            return cleanedText
        case .auto:
            if !trimmedPinyin.isEmpty {
                return pinyinText
            }
            return cleanedText
        case .english, .spanish:
            return cleanedText
        }
    }
}
