//
//  OCREngine.swift
//  llh
//

import Foundation

enum OCREngine: String, CaseIterable, Identifiable {
    case local
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: return "Локально"
        case .ai: return "AI"
        }
    }
}
