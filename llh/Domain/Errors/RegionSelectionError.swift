//
//  RegionSelectionError.swift
//  llh
//

import Foundation

enum RegionSelectionError: LocalizedError {
    case cancelled
    case noScreen

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Выделение отменено."
        case .noScreen:
            return "Не удалось получить экран."
        }
    }
}
