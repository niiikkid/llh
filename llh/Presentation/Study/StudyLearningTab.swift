//
//  StudyLearningTab.swift
//  llh
//

import Foundation

enum StudyLearningTab: String, CaseIterable, Identifiable {
    case words
    case grammar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .words: return "Перевод слов"
        case .grammar: return "Грамматика"
        }
    }
}
