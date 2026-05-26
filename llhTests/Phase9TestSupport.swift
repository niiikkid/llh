//
//  Phase9TestSupport.swift
//  llhTests
//
//  Shared fakes and helpers for Phase 9 integration tests.
//

import CoreGraphics
import Foundation
@testable import llh

enum Phase9TestSupport {
    static func makeTemporaryLocations() -> HistoryStorageLocations {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("llh.phase9.\(UUID().uuidString)", isDirectory: true)
        return HistoryStorageLocations(applicationSupportDirectory: directory)
    }

    static func makeTestCGImage() -> CGImage {
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
}

@MainActor
final class Phase9FakeRegionSelecting: RegionSelecting {
    var rectToReturn = CGRect(x: 0, y: 0, width: 40, height: 40)

    func selectRegion() async throws -> CGRect {
        rectToReturn
    }

    func cancelActiveSelection() {}
}

struct Phase9FakePermissionService: ScreenRecordingPermissionChecking {
    var permissionStatus: ScreenRecordingPermissionStatus

    func requestPermission() -> Bool {
        permissionStatus.isAuthorized
    }

    func openSystemSettings() {}
}

struct Phase9FakeScreenCapturing: ScreenCapturing {
    var image: CGImage

    func capture(region: CGRect) async throws -> CGImage {
        try Task.checkCancellation()
        return image
    }
}

struct Phase9FakeOCRServing: OCRServing {
    var result: OCRResult

    func recognizeText(in image: CGImage) async throws -> OCRResult {
        result
    }
}

struct Phase9FakeOpenAIOCRServing: OpenAIOCRServing {
    var result: OCRResult

    func recognizeTextInImage(apiKey: String, modelID: String, image: CGImage) async throws -> OCRResult {
        result
    }
}

/// Returns a snapshot that does not match what was saved (for migration verification failure tests).
final class Phase9MismatchOnLoadHistoryRepository: HistoryRepository {
    private let inner: SQLiteHistoryRepository
    private var loadInvocationCount = 0

    init(inner: SQLiteHistoryRepository) {
        self.inner = inner
    }

    func loadStore() throws -> HistoryStoreSnapshot {
        loadInvocationCount += 1
        if loadInvocationCount == 1 {
            let profile = LearningProfile.defaultProfile()
            return HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)
        }
        return try inner.loadStore()
    }

    func saveStore(_ snapshot: HistoryStoreSnapshot) throws {
        try inner.saveStore(snapshot)
    }
}

final class Phase9IntegrationFakeOpenAIServing: OpenAIServing {
    var formattedResult = StructuredFormattedText(
        cleanedText: "cleaned",
        pinyinText: "pin",
        russianTranslation: "перевод"
    )
    private(set) var formatCallCount = 0
    private(set) var lastFormattedRawText: String?

    func fetchModels(apiKey: String) async throws -> [OpenAIModel] {
        [OpenAIModel(id: "gpt-4o-mini")]
    }

    func recognizeTextInImage(apiKey: String, modelID: String, image: CGImage) async throws -> String {
        ""
    }

    func formatRecognizedText(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        formatCallCount += 1
        lastFormattedRawText = rawText
        return formattedResult
    }

    func buildWordsStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        WordStudyPayload(entries: [])
    }
}

final class Phase9InMemorySettingsRepository: SettingsRepository {
    var selectedModelID: String? = "gpt-4o-mini"
    var selectedLearningLanguageRawValue = LearningLanguage.chinese.rawValue
    var cachedModels: [OpenAIModel] = [OpenAIModel(id: "gpt-4o-mini")]
    var selectedOCREngineRawValue = OCREngine.local.rawValue
    var translationOverlayMinimumDuration = 3.0
    var translationOverlaySecondsPerWord = 0.33
}

final class Phase9InMemoryAPIKeyRepository: APIKeyRepository {
    var key: String? = "sk-test"

    func loadAPIKey() -> String? {
        key
    }

    func saveAPIKey(_ key: String) throws {
        self.key = key
    }

    func deleteAPIKey() throws {
        key = nil
    }
}
