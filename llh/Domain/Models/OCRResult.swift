//
//  OCRResult.swift
//  llh
//

import Foundation

/// Structured OCR output shared by local Vision and OpenAI vision flows.
struct OCRResult: Sendable, Equatable {
    let text: String
    let lines: [String]

    nonisolated var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    nonisolated init(text: String, lines: [String]) {
        self.text = text
        self.lines = lines
    }

    nonisolated init(normalizedText: String) {
        let splitLines = normalizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        self.init(
            text: normalizedText,
            lines: splitLines.isEmpty && !normalizedText.isEmpty ? [normalizedText] : splitLines
        )
    }
}
