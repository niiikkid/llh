//
//  Phase7CaptureOCRTests.swift
//  llhTests
//

import CoreGraphics
import Foundation
import Testing
@testable import llh

struct Phase7CaptureOCRTests {
    @Test
    func ocrResult_emptyWhenTextIsWhitespaceOnly() {
        let result = OCRResult(normalizedText: "   \n  ")
        #expect(result.isEmpty)
    }

    @Test
    func ocrResult_preservesLinesFromNormalizedText() {
        let result = OCRResult(normalizedText: "alpha\nbeta")
        #expect(result.text == "alpha\nbeta")
        #expect(result.lines == ["alpha", "beta"])
    }

    @Test
    func screenRecordingPermissionService_mapsPreflightToStatus() {
        let service = ScreenRecordingPermissionService()
        let status = service.permissionStatus
        let expected: ScreenRecordingPermissionStatus = service.hasPermission ? .authorized : .denied
        #expect(status == expected)
    }

    @Test
    func ocrImagePreprocessor_encodesJPEGOffMainActor() async throws {
        let image = makeTestCGImage()
        let data = try await OCRImagePreprocessor.jpegData(from: image)
        #expect(!data.isEmpty)
        #expect(data.starts(with: [0xFF, 0xD8, 0xFF]))
    }

    @Test
    func ocrImagePreprocessor_propagatesCancellation() async {
        let image = makeTestCGImage()
        let task = Task {
            try await OCRImagePreprocessor.jpegData(from: image)
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected CancellationError")
        } catch is CancellationError {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    @MainActor
    func captureRegionUseCase_propagatesCancellationDuringCapture() async {
        let useCase = CaptureRegionUseCase(
            permissionService: Phase7FakePermissionService(permissionStatus: .authorized),
            regionSelectionService: Phase7FakeRegionSelecting(),
            screenshotService: Phase7CancellingScreenCapturing(),
            recognizeTextUseCase: RecognizeTextUseCase(
                ocrService: Phase7FakeOCRServing(result: OCRResult(normalizedText: "x")),
                openAIOCRService: Phase7FakeOpenAIOCRServing(result: OCRResult(normalizedText: "x"))
            )
        )

        let task = Task {
            try await useCase.execute(
                configuration: CaptureRegionConfiguration(
                    ocrEngine: .local,
                    apiKey: nil,
                    selectedModelID: nil
                )
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected CancellationError")
        } catch is CancellationError {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@MainActor
private final class Phase7FakeRegionSelecting: RegionSelecting {
    func selectRegion() async throws -> CGRect {
        CGRect(x: 0, y: 0, width: 10, height: 10)
    }

    func cancelActiveSelection() {}
}

private struct Phase7FakePermissionService: ScreenRecordingPermissionChecking {
    let permissionStatus: ScreenRecordingPermissionStatus

    func requestPermission() -> Bool { permissionStatus.isAuthorized }

    func openSystemSettings() {}
}

private struct Phase7CancellingScreenCapturing: ScreenCapturing {
    func capture(region: CGRect) async throws -> CGImage {
        try Task.checkCancellation()
        return makeTestCGImage()
    }
}

private struct Phase7FakeOCRServing: OCRServing {
    let result: OCRResult

    func recognizeText(in image: CGImage) async throws -> OCRResult {
        result
    }
}

private struct Phase7FakeOpenAIOCRServing: OpenAIOCRServing {
    let result: OCRResult

    func recognizeTextInImage(apiKey: String, modelID: String, image: CGImage) async throws -> OCRResult {
        result
    }
}

private func makeTestCGImage() -> CGImage {
    let width = 8
    let height = 8
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}
