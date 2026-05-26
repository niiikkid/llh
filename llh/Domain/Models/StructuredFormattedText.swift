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

    /// Основная строка для overlay и расчёта длительности: пиньинь → очищенный исходник → русский перевод.
    var overlayPrimaryText: String {
        let trimmedPinyin = pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPinyin.isEmpty {
            return trimmedPinyin
        }

        let trimmedCleaned = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCleaned.isEmpty {
            return trimmedCleaned
        }

        return russianTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Основная строка в detail UI и overlay: пиньинь для китайского/авто с пиньинем, иначе очищенный исходник.
    func primaryDisplayLine(learningLanguage: LearningLanguage) -> String {
        if usesPinyinAsPrimary(learningLanguage: learningLanguage) {
            let trimmedPinyin = pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedPinyin.isEmpty ? "—" : pinyinText
        }
        return cleanedText
    }

    /// Показывать очищенный исходник над основной строкой (китайский/авто с пиньинем).
    func showsSourceCaptionAbovePrimary(learningLanguage: LearningLanguage) -> Bool {
        usesPinyinAsPrimary(learningLanguage: learningLanguage)
    }

    func usesPinyinAsPrimary(learningLanguage: LearningLanguage) -> Bool {
        switch learningLanguage {
        case .chinese:
            return true
        case .auto:
            return !pinyinText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .english, .spanish:
            return false
        }
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
