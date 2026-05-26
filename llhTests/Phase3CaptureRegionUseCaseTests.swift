//
//  Phase3CaptureRegionUseCaseTests.swift
//  llhTests
//

import CoreGraphics
import Foundation
import Testing
@testable import llh

@MainActor
private final class FakeRegionSelecting: RegionSelecting {
    var rectToReturn = CGRect(x: 0, y: 0, width: 100, height: 100)
    var errorToThrow: Error?

    func selectRegion() async throws -> CGRect {
        if let errorToThrow {
            throw errorToThrow
        }
        return rectToReturn
    }
}

private struct FakePermissionService: ScreenRecordingPermissionChecking {
    var hasPermission: Bool

    func requestPermission() -> Bool { hasPermission }

    func openSystemSettings() {}
}

private struct FakeScreenCapturing: ScreenCapturing {
    let image: CGImage

    func capture(region: CGRect) async throws -> CGImage {
        image
    }
}

private struct FakeOCRServing: OCRServing {
    var recognizedText: String

    func recognizeText(in image: CGImage) async throws -> String {
        recognizedText
    }
}

private struct FakeOpenAIServing: OpenAIServing {
    var recognizedText: String

    func fetchModels(apiKey: String) async throws -> [OpenAIModel] { [] }

    func recognizeTextInImage(apiKey: String, modelID: String, image: CGImage) async throws -> String {
        recognizedText
    }

    func formatRecognizedText(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        StructuredFormattedText(cleanedText: rawText, pinyinText: "", russianTranslation: "")
    }

    func buildWordsStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        WordStudyPayload(entries: [])
    }

    func buildPhrasesStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> PhraseStudyPayload {
        PhraseStudyPayload(entries: [])
    }

    func buildGrammarStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> GrammarExplanationPayload {
        GrammarExplanationPayload(structures: [])
    }
}

private enum TestImageFactory {
    static func makeCGImage() -> CGImage {
        let width = 4
        let height = 4
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
}

struct Phase3CaptureRegionUseCaseTests {
    @Test
    @MainActor
    func captureRegionUseCase_returnsPermissionDeniedWithoutServices() async throws {
        let useCase = CaptureRegionUseCase(
            permissionService: FakePermissionService(hasPermission: false),
            regionSelectionService: FakeRegionSelecting(),
            screenshotService: FakeScreenCapturing(image: TestImageFactory.makeCGImage()),
            recognizeTextUseCase: RecognizeTextUseCase(
                ocrService: FakeOCRServing(recognizedText: "你好"),
                openAIService: FakeOpenAIServing(recognizedText: "你好")
            )
        )

        let outcome = try await useCase.execute(
            configuration: CaptureRegionConfiguration(
                ocrEngine: .local,
                apiKey: nil,
                selectedModelID: nil
            )
        )

        if case .permissionDenied = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected permissionDenied, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func captureRegionUseCase_returnsCapturedText() async throws {
        let image = TestImageFactory.makeCGImage()
        let useCase = CaptureRegionUseCase(
            permissionService: FakePermissionService(hasPermission: true),
            regionSelectionService: FakeRegionSelecting(),
            screenshotService: FakeScreenCapturing(image: image),
            recognizeTextUseCase: RecognizeTextUseCase(
                ocrService: FakeOCRServing(recognizedText: "你好"),
                openAIService: FakeOpenAIServing(recognizedText: "你好")
            )
        )

        let outcome = try await useCase.execute(
            configuration: CaptureRegionConfiguration(
                ocrEngine: .local,
                apiKey: nil,
                selectedModelID: nil
            )
        )

        guard case .captured(let capturedImage, let text) = outcome else {
            Issue.record("Expected captured outcome, got \(outcome)")
            return
        }
        #expect(text == "你好")
        #expect(capturedImage.width == image.width)
    }

    @Test
    @MainActor
    func captureRegionUseCase_returnsNoTextFound() async throws {
        let image = TestImageFactory.makeCGImage()
        let useCase = CaptureRegionUseCase(
            permissionService: FakePermissionService(hasPermission: true),
            regionSelectionService: FakeRegionSelecting(),
            screenshotService: FakeScreenCapturing(image: image),
            recognizeTextUseCase: RecognizeTextUseCase(
                ocrService: FakeOCRServing(recognizedText: ""),
                openAIService: FakeOpenAIServing(recognizedText: "")
            )
        )

        let outcome = try await useCase.execute(
            configuration: CaptureRegionConfiguration(
                ocrEngine: .local,
                apiKey: nil,
                selectedModelID: nil
            )
        )

        guard case .noTextFound(let emptyImage) = outcome else {
            Issue.record("Expected noTextFound outcome, got \(outcome)")
            return
        }
        #expect(emptyImage.width == image.width)
    }

    @Test
    @MainActor
    func captureRegionUseCase_returnsSelectionCancelled() async throws {
        let regionSelector = FakeRegionSelecting()
        regionSelector.errorToThrow = RegionSelectionError.cancelled
        let useCase = CaptureRegionUseCase(
            permissionService: FakePermissionService(hasPermission: true),
            regionSelectionService: regionSelector,
            screenshotService: FakeScreenCapturing(image: TestImageFactory.makeCGImage()),
            recognizeTextUseCase: RecognizeTextUseCase(
                ocrService: FakeOCRServing(recognizedText: "你好"),
                openAIService: FakeOpenAIServing(recognizedText: "你好")
            )
        )

        let outcome = try await useCase.execute(
            configuration: CaptureRegionConfiguration(
                ocrEngine: .local,
                apiKey: nil,
                selectedModelID: nil
            )
        )

        if case .selectionCancelled = outcome {
            #expect(Bool(true))
        } else {
            Issue.record("Expected selectionCancelled, got \(outcome)")
        }
    }

    @Test
    @MainActor
    func recognizeTextUseCase_usesLocalOCR() async throws {
        let useCase = RecognizeTextUseCase(
            ocrService: FakeOCRServing(recognizedText: "local"),
            openAIService: FakeOpenAIServing(recognizedText: "ai")
        )

        let text = try await useCase.execute(
            image: TestImageFactory.makeCGImage(),
            configuration: RecognizeTextConfiguration(
                ocrEngine: .local,
                apiKey: nil,
                selectedModelID: nil
            )
        )

        #expect(text == "local")
    }

    @Test
    @MainActor
    func recognizeTextUseCase_usesOpenAIWhenAIEngineSelected() async throws {
        let useCase = RecognizeTextUseCase(
            ocrService: FakeOCRServing(recognizedText: "local"),
            openAIService: FakeOpenAIServing(recognizedText: "ai")
        )

        let text = try await useCase.execute(
            image: TestImageFactory.makeCGImage(),
            configuration: RecognizeTextConfiguration(
                ocrEngine: .ai,
                apiKey: "sk-test",
                selectedModelID: "gpt-test"
            )
        )

        #expect(text == "ai")
    }

    @Test
    @MainActor
    func recognizeTextUseCase_requiresAPIKeyForAIEngine() async {
        let useCase = RecognizeTextUseCase(
            ocrService: FakeOCRServing(recognizedText: "local"),
            openAIService: FakeOpenAIServing(recognizedText: "ai")
        )

        do {
            _ = try await useCase.execute(
                image: TestImageFactory.makeCGImage(),
                configuration: RecognizeTextConfiguration(
                    ocrEngine: .ai,
                    apiKey: nil,
                    selectedModelID: "gpt-test"
                )
            )
            Issue.record("Expected OpenAIServiceError.invalidTokenFormat")
        } catch let error as OpenAIServiceError {
            if case .invalidTokenFormat = error {
                #expect(Bool(true))
            } else {
                Issue.record("Unexpected OpenAIServiceError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
