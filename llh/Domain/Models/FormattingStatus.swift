//
//  FormattingStatus.swift
//  llh
//

import Foundation

enum FormattingStatus: String, Codable {
    case notRequested
    case processing
    case succeeded
    case failed
}
