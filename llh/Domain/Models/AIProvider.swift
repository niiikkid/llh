//
//  AIProvider.swift
//  llh
//

import Foundation

/// LLM provider used for text (translation / study). AI OCR always stays on OpenAI.
enum AIProvider: String, CaseIterable, Identifiable, Hashable, Sendable {
    case openAI
    case deepSeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .deepSeek: "DeepSeek"
        }
    }

    var apiBaseURL: URL {
        switch self {
        case .openAI:
            URL(string: "https://api.openai.com/v1")!
        case .deepSeek:
            URL(string: "https://api.deepseek.com")!
        }
    }

    var keychainService: String {
        switch self {
        case .openAI: "local.llh.ocr.openai"
        case .deepSeek: "local.llh.ocr.deepseek"
        }
    }

    var keychainAccount: String {
        switch self {
        case .openAI: "openai-api-token"
        case .deepSeek: "deepseek-api-token"
        }
    }
}
