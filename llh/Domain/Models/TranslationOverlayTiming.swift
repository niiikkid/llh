//
//  TranslationOverlayTiming.swift
//  llh
//

import Foundation

struct LatestTranslationLookup {
    static func latestFormattedText(in profiles: [LearningProfile]) -> StructuredFormattedText? {
        profiles
            .flatMap(\.history)
            .compactMap { entry -> (Date, StructuredFormattedText)? in
                guard let formattedText = entry.formattedText, formattedText.hasContent else { return nil }
                return (entry.createdAt, formattedText)
            }
            .max(by: { $0.0 < $1.0 })?
            .1
    }
}

struct TranslationOverlayTiming {
    static func duration(
        for formattedText: StructuredFormattedText,
        minimumDuration: Double,
        secondsPerWord: Double
    ) -> Double {
        let clampedMinimumDuration = min(max(minimumDuration, 1), 15)
        let clampedSecondsPerWord = min(max(secondsPerWord, 0.1), 2)
        let wordCount = wordCount(in: visibleTexts(for: formattedText))
        let calculatedDuration = Double(wordCount) * clampedSecondsPerWord
        return max(clampedMinimumDuration, calculatedDuration)
    }

    static func visibleTexts(for formattedText: StructuredFormattedText) -> [String] {
        let primaryText = overlayPrimaryText(for: formattedText)
        let secondaryText = formattedText.russianTranslation.trimmingCharacters(in: .whitespacesAndNewlines)

        if secondaryText.isEmpty || primaryText == secondaryText {
            return [primaryText]
        }

        return [primaryText, secondaryText]
    }

    static func wordCount(in texts: [String]) -> Int {
        texts
            .flatMap { text in
                text
                    .split(whereSeparator: \.isWhitespace)
                    .map(String.init)
            }
            .count
    }

    private static func overlayPrimaryText(for formattedText: StructuredFormattedText) -> String {
        let trimmedPinyin = formattedText.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPinyin.isEmpty {
            return trimmedPinyin
        }

        let trimmedCleaned = formattedText.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCleaned.isEmpty {
            return trimmedCleaned
        }

        return formattedText.russianTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
