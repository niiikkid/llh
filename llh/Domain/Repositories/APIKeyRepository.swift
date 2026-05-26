//
//  APIKeyRepository.swift
//  llh
//

import Foundation

protocol APIKeyRepository {
    func loadAPIKey() -> String?
    func saveAPIKey(_ key: String) throws
    func deleteAPIKey() throws
}
