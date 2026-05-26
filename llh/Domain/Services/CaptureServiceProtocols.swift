//
//  CaptureServiceProtocols.swift
//  llh
//

import CoreGraphics
import Foundation

protocol ScreenRecordingPermissionChecking: Sendable {
    var permissionStatus: ScreenRecordingPermissionStatus { get }
    var hasPermission: Bool { get }
    @discardableResult
    func requestPermission() -> Bool
    func openSystemSettings()
}

extension ScreenRecordingPermissionChecking {
    var hasPermission: Bool {
        permissionStatus.isAuthorized
    }
}

@MainActor
protocol RegionSelecting: AnyObject {
    func selectRegion() async throws -> CGRect
    func cancelActiveSelection()
}

protocol ScreenCapturing: Sendable {
    func capture(region: CGRect) async throws -> CGImage
}

protocol OCRServing: Sendable {
    func recognizeText(in image: CGImage) async throws -> OCRResult
}

extension ScreenRecordingPermissionService: ScreenRecordingPermissionChecking {}

extension RegionSelectionService: RegionSelecting {}

extension ScreenCaptureKitCaptureService: ScreenCapturing {}

extension VisionOCRService: OCRServing {}
