//
//  CaptureServiceProtocols.swift
//  llh
//

import CoreGraphics
import Foundation

protocol ScreenRecordingPermissionChecking {
    var hasPermission: Bool { get }
    @discardableResult
    func requestPermission() -> Bool
    func openSystemSettings()
}

protocol RegionSelecting: AnyObject {
    func selectRegion() async throws -> CGRect
}

protocol ScreenCapturing {
    func capture(region: CGRect) async throws -> CGImage
}

protocol OCRServing {
    func recognizeText(in image: CGImage) async throws -> String
}

extension ScreenRecordingPermissionService: ScreenRecordingPermissionChecking {}

extension RegionSelectionService: RegionSelecting {}

extension ScreenshotService: ScreenCapturing {}

extension OCRService: OCRServing {}
