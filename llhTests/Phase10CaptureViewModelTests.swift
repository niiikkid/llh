//
//  Phase10CaptureViewModelTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

@MainActor
struct Phase10CaptureViewModelTests {
    @Test
    func hotkeyWhileProcessing_cancelsActiveCapture() async throws {
        let regionSelector = Phase10BlockingRegionSelecting()
        let harness = try makeHarness(regionSelectionService: regionSelector)

        harness.capture.triggerCapture()

        for _ in 0..<200 {
            if harness.capture.isProcessing {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(harness.capture.isProcessing)

        harness.capture.triggerCaptureFromHotkey()

        for _ in 0..<200 {
            if !harness.capture.isProcessing,
               harness.capture.statusMessage.localizedCaseInsensitiveContains("отмен")
            {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(!harness.capture.isProcessing)
        #expect(regionSelector.cancelCallCount == 1)
        #expect(harness.capture.statusMessage.localizedCaseInsensitiveContains("отмен"))
    }

    private struct Harness {
        let capture: CaptureViewModel
    }

    private func makeHarness(
        regionSelectionService: RegionSelecting
    ) throws -> Harness {
        let locations = Phase9TestSupport.makeTemporaryLocations()
        let database = try HistoryDatabase(locations: locations)
        let historyRepository = SQLiteHistoryRepository(database: database)
        let manageHistoryUseCase = ManageHistoryUseCase(historyRepository: historyRepository)
        let manageProfilesUseCase = ManageProfilesUseCase(manageHistoryUseCase: manageHistoryUseCase)
        let settingsRepository = Phase9InMemorySettingsRepository()
        let apiKeyRepository = Phase9InMemoryAPIKeyRepository()
        let openAI = Phase9IntegrationFakeOpenAIServing()
        let manageOpenAISettingsUseCase = ManageOpenAISettingsUseCase(
            settingsRepository: settingsRepository,
            apiKeyRepository: apiKeyRepository,
            openAIService: openAI
        )
        let settings = SettingsViewModel(
            manageOpenAISettingsUseCase: manageOpenAISettingsUseCase,
            translationOverlayService: TranslationOverlayService()
        )
        let history = HistoryViewModel(
            manageHistoryUseCase: manageHistoryUseCase,
            manageProfilesUseCase: manageProfilesUseCase,
            defaultLearningLanguage: { settings.defaultNewProfileLearningLanguage }
        )
        let captureRegionUseCase = CaptureRegionUseCase(
            permissionService: Phase9FakePermissionService(permissionStatus: .authorized),
            regionSelectionService: regionSelectionService,
            screenshotService: Phase9FakeScreenCapturing(image: Phase9TestSupport.makeTestCGImage()),
            recognizeTextUseCase: RecognizeTextUseCase(
                ocrService: Phase9FakeOCRServing(result: OCRResult(normalizedText: "line")),
                openAIOCRService: Phase9FakeOpenAIOCRServing(result: OCRResult(normalizedText: "line"))
            )
        )
        let capture = CaptureViewModel(
            permissionService: Phase9FakePermissionService(permissionStatus: .authorized),
            captureRegionUseCase: captureRegionUseCase,
            settings: settings,
            history: history,
            translationOverlayService: TranslationOverlayService(),
            shouldUseCompactOverlay: { false }
        )
        return Harness(capture: capture)
    }
}

@MainActor
private final class Phase10BlockingRegionSelecting: RegionSelecting {
    private var waitContinuation: CheckedContinuation<Void, Never>?
    private(set) var cancelCallCount = 0

    func selectRegion() async throws -> CGRect {
        await withCheckedContinuation { continuation in
            waitContinuation = continuation
        }
        throw RegionSelectionError.cancelled
    }

    func cancelActiveSelection() {
        cancelCallCount += 1
        waitContinuation?.resume()
        waitContinuation = nil
    }
}
