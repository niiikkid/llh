//
//  ViewState.swift
//  llh
//

import Foundation

enum LoadingState: Equatable {
    case idle
    case loading
    case succeeded
    case failed
}

struct AlertState: Equatable {
    var message: String?

    static let empty = AlertState(message: nil)
}

enum ViewState<Content: Equatable>: Equatable {
    case empty
    case loading
    case content(Content)
    case failed(message: String)
}
