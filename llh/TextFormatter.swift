//
//  TextFormatter.swift
//  llh
//

import Foundation

enum TextFormatter {
    static func normalizeRecognizedLines(_ lines: [String]) -> String {
        lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
