//
//  KeychainAPIKeyRepository.swift
//  llh
//

import Foundation

struct KeychainAPIKeyRepository: APIKeyRepository {
    private let stores: [AIProvider: any OpenAITokenStoring]

    init(tokenStore: any OpenAITokenStoring) {
        self.stores = [.openAI: tokenStore]
    }

    init(stores: [AIProvider: any OpenAITokenStoring]) {
        self.stores = stores
    }

    init() {
        self.stores = [
            .openAI: KeychainOpenAITokenStore(
                service: AIProvider.openAI.keychainService,
                account: AIProvider.openAI.keychainAccount
            ),
            .deepSeek: KeychainOpenAITokenStore(
                service: AIProvider.deepSeek.keychainService,
                account: AIProvider.deepSeek.keychainAccount
            )
        ]
    }

    func loadAPIKey(for provider: AIProvider) -> String? {
        stores[provider]?.loadToken()
    }

    func saveAPIKey(_ key: String, for provider: AIProvider) throws {
        try store(for: provider).saveToken(key)
    }

    func deleteAPIKey(for provider: AIProvider) throws {
        try store(for: provider).deleteToken()
    }

    private func store(for provider: AIProvider) -> any OpenAITokenStoring {
        stores[provider] ?? KeychainOpenAITokenStore(
            service: provider.keychainService,
            account: provider.keychainAccount
        )
    }
}
