//
//  HistoryRepository.swift
//  llh
//

import Foundation

protocol HistoryRepository {
    func loadStore() throws -> HistoryStoreSnapshot
    func saveStore(_ snapshot: HistoryStoreSnapshot) throws
}
