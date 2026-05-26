//
//  ScreenCaptureKitCaptureService.swift
//  llh
//

import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// ScreenCaptureKit-backed region capture. Hides framework details behind `ScreenCapturing`.
struct ScreenCaptureKitCaptureService: Sendable {
    nonisolated init() {}

    enum CaptureError: LocalizedError {
        case failed
        case noDisplayForRegion

        var errorDescription: String? {
            switch self {
            case .failed:
                return "Не удалось сделать снимок экрана."
            case .noDisplayForRegion:
                return "Не удалось определить экран для выделенной области."
            }
        }
    }

    nonisolated func capture(region: CGRect) async throws -> CGImage {
        try Task.checkCancellation()

        if #available(macOS 15.2, *) {
            return try await captureWithRectAPI(region: region)
        }
        return try await captureWithContentFilter(region: region)
    }

    @available(macOS 15.2, *)
    private nonisolated func captureWithRectAPI(region: CGRect) async throws -> CGImage {
        try Task.checkCancellation()
        let screenKitRect = convertToScreenKitGlobalRect(region)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
            SCScreenshotManager.captureImage(in: screenKitRect) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image else {
                    continuation.resume(throwing: CaptureError.failed)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    private nonisolated func captureWithContentFilter(region: CGRect) async throws -> CGImage {
        try Task.checkCancellation()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let center = CGPoint(x: region.midX, y: region.midY)

        guard let display = content.displays.first(where: { $0.frame.contains(center) }) else {
            throw CaptureError.noDisplayForRegion
        }

        let localX = region.origin.x - display.frame.origin.x
        let localY = display.frame.maxY - region.maxY
        let sourceRect = CGRect(
            x: localX,
            y: localY,
            width: region.width,
            height: region.height
        ).standardized

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect
        configuration.width = Int(sourceRect.width.rounded())
        configuration.height = Int(sourceRect.height.rounded())
        configuration.capturesAudio = false

        try Task.checkCancellation()

        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image else {
                    continuation.resume(throwing: CaptureError.failed)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    private nonisolated func convertToScreenKitGlobalRect(_ region: CGRect) -> CGRect {
        let desktopFrame = NSScreen.screens.map(\.frame).reduce(CGRect.null) { partial, frame in
            partial.union(frame)
        }

        guard !desktopFrame.isNull else {
            return region
        }

        let topLeftY = desktopFrame.maxY - region.maxY
        return CGRect(
            x: region.origin.x,
            y: topLeftY,
            width: region.width,
            height: region.height
        ).standardized
    }
}
