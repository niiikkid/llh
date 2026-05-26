//
//  KeychainAPIKeyRepository.swift
//  llh
//

import Foundation

struct KeychainAPIKeyRepository: APIKeyRepository {
    private let tokenStore: OpenAITokenStoring

    init(tokenStore: OpenAITokenStoring = KeychainOpenAITokenStore()) {
        self.tokenStore = tokenStore
    }

    func loadAPIKey() -> String? {
        tokenStore.loadToken()
    }

    func saveAPIKey(_ key: String) throws {
        try tokenStore.saveToken(key)
    }

    func deleteAPIKey() throws {
        try tokenStore.deleteToken()
    }
}
