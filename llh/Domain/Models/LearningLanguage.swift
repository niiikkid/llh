//
//  LearningLanguage.swift
//  llh
//

import Foundation

enum LearningLanguage: String, CaseIterable, Identifiable, Codable {
    case auto
    case english
    case spanish
    case chinese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Автоопределение"
        case .english: return "Английский"
        case .spanish: return "Испанский"
        case .chinese: return "Китайский"
        }
    }

    var supportsWordStudy: Bool {
        self != .auto
    }

    /// Flag emoji for session language UI; `auto` uses a globe symbol in views instead.
    var flagEmoji: String? {
        switch self {
        case .auto: return nil
        case .english: return "🇬🇧"
        case .spanish: return "🇪🇸"
        case .chinese: return "🇨🇳"
        }
    }
}
