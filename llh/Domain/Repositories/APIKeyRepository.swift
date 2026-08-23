//
//  APIKeyRepository.swift
//  llh
//

import Foundation

protocol APIKeyRepository {
    func loadAPIKey(for provider: AIProvider) -> String?
    func saveAPIKey(_ key: String, for provider: AIProvider) throws
    func deleteAPIKey(for provider: AIProvider) throws
}

extension APIKeyRepository {
    func loadAPIKey() -> String? {
        loadAPIKey(for: .openAI)
    }

    func saveAPIKey(_ key: String) throws {
        try saveAPIKey(key, for: .openAI)
    }

    func deleteAPIKey() throws {
        try deleteAPIKey(for: .openAI)
    }
}
