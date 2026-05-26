//
//  CaptureRegionUseCase.swift
//  llh
//

import CoreGraphics
import Foundation

struct CaptureRegionConfiguration: Sendable {
    let ocrEngine: OCREngine
    let apiKey: String?
    let selectedModelID: String?
}

enum CaptureRegionOutcome: Sendable {
    case permissionDenied
    case selectionCancelled
    case noTextFound(image: CGImage)
    case captured(image: CGImage, text: String)
}

@MainActor
struct CaptureRegionUseCase {
    private let permissionService: ScreenRecordingPermissionChecking
    private let regionSelectionService: RegionSelecting
    private let screenshotService: ScreenCapturing
    private let recognizeTextUseCase: RecognizeTextUseCase

    init(
        permissionService: ScreenRecordingPermissionChecking,
        regionSelectionService: RegionSelecting,
        screenshotService: ScreenCapturing,
        recognizeTextUseCase: RecognizeTextUseCase
    ) {
        self.permissionService = permissionService
        self.regionSelectionService = regionSelectionService
        self.screenshotService = screenshotService
        self.recognizeTextUseCase = recognizeTextUseCase
    }

    func execute(configuration: CaptureRegionConfiguration) async throws -> CaptureRegionOutcome {
        guard permissionService.hasPermission else {
            return .permissionDenied
        }

        let selectedRect: CGRect
        do {
            selectedRect = try await regionSelectionService.selectRegion()
        } catch RegionSelectionError.cancelled {
            return .selectionCancelled
        }

        let image = try await screenshotService.capture(region: selectedRect)
        let text = try await recognizeTextUseCase.execute(
            image: image,
            configuration: RecognizeTextConfiguration(
                ocrEngine: configuration.ocrEngine,
                apiKey: configuration.apiKey,
                selectedModelID: configuration.selectedModelID
            )
        )

        guard !text.isEmpty else {
            return .noTextFound(image: image)
        }

        return .captured(image: image, text: text)
    }
}
