//
//  ScreenRecordingPermissionStatus.swift
//  llh
//

import Foundation

enum ScreenRecordingPermissionStatus: Sendable, Equatable {
    case authorized
    case denied

    var isAuthorized: Bool {
        if case .authorized = self { return true }
        return false
    }
}
