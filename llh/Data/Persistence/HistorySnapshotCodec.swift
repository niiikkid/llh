//
//  HistorySnapshotCodec.swift
//  llh
//

import Foundation

enum HistorySnapshotCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func encodeFormattedText(_ value: StructuredFormattedText?) throws -> String? {
        guard let value else { return nil }
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8)
    }

    static func decodeFormattedText(_ json: String?) throws -> StructuredFormattedText? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try decoder.decode(StructuredFormattedText.self, from: data)
    }

    static func encodeStudyMaterials(_ value: StudyMaterials) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw HistoryPersistenceError.encodingFailed
        }
        return string
    }

    static func decodeStudyMaterials(_ json: String) throws -> StudyMaterials {
        guard let data = json.data(using: .utf8) else {
            throw HistoryPersistenceError.decodingFailed
        }
        return try decoder.decode(StudyMaterials.self, from: data)
    }
}

enum HistoryPersistenceError: Error, Equatable {
    case encodingFailed
    case decodingFailed
    case migrationVerificationFailed
    case invalidRow
}
