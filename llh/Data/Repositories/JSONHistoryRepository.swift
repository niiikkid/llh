//
//  JSONHistoryRepository.swift
//  llh
//

import Foundation

struct JSONHistoryRepository: HistoryRepository {
    private let persistence: HistoryPersistenceService

    init(persistence: HistoryPersistenceService = HistoryPersistenceService()) {
        self.persistence = persistence
    }

    func loadStore() throws -> HistoryStoreSnapshot {
        try persistence.loadStore()
    }

    func saveStore(_ snapshot: HistoryStoreSnapshot) throws {
        try persistence.saveStore(snapshot)
    }
}
