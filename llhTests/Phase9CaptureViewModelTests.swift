//
//  Phase9CaptureViewModelTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

@MainActor
struct Phase9CaptureViewModelTests {
  @Test
  func permissionDenied_showsHelpAndStatusMessage() async throws {
    let harness = try makeHarness(permissionStatus: .denied)
    harness.capture.refreshPermissionState()

    #expect(harness.capture.showPermissionHelp)
    #expect(harness.capture.permissionStatus == .denied)

    harness.capture.triggerCapture()
    await waitForCaptureStatus(harness.capture, containing: "Screen Recording")

    #expect(harness.capture.showPermissionHelp)
    #expect(harness.capture.isProcessing == false)
  }

  @Test
  func successfulCapture_insertsHistoryEntry() async throws {
    let harness = try makeHarness(permissionStatus: .authorized)
    harness.history.loadFromDisk()
    #expect(harness.history.selectedProfileIndex != nil)
    let initialCount = harness.history.history.count

    harness.capture.triggerCapture()
    await waitForHistoryCount(harness.history, greaterThan: initialCount)

    #expect(harness.capture.showPermissionHelp == false)
    #expect(harness.history.history.first?.text == "captured line")
    #expect(harness.capture.statusMessage.contains("Форматирую"))
  }

  @Test
  func refreshPermissionState_authorizedUpdatesStatusMessage() throws {
    let harness = try makeHarness(permissionStatus: .authorized)
    harness.capture.refreshPermissionState()

    #expect(harness.capture.permissionStatus == .authorized)
    #expect(harness.capture.showPermissionHelp == false)
    #expect(harness.capture.statusMessage.contains("Готово"))
  }

  private struct Harness {
    let capture: CaptureViewModel
    let history: HistoryViewModel
  }

  private func makeHarness(permissionStatus: ScreenRecordingPermissionStatus) throws -> Harness {
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
    let image = Phase9TestSupport.makeTestCGImage()
    let captureRegionUseCase = CaptureRegionUseCase(
      permissionService: Phase9FakePermissionService(permissionStatus: permissionStatus),
      regionSelectionService: Phase9FakeRegionSelecting(),
      screenshotService: Phase9FakeScreenCapturing(image: image),
      recognizeTextUseCase: RecognizeTextUseCase(
        ocrService: Phase9FakeOCRServing(result: OCRResult(normalizedText: "captured line")),
        openAIOCRService: Phase9FakeOpenAIOCRServing(result: OCRResult(normalizedText: "unused"))
      )
    )
    let capture = CaptureViewModel(
      permissionService: Phase9FakePermissionService(permissionStatus: permissionStatus),
      captureRegionUseCase: captureRegionUseCase,
      settings: settings,
      history: history,
      translationOverlayService: TranslationOverlayService(),
      shouldUseCompactOverlay: { false }
    )
    return Harness(capture: capture, history: history)
  }

  private func waitForCaptureStatus(
    _ capture: CaptureViewModel,
    containing substring: String
  ) async {
    for _ in 0..<200 {
      if capture.statusMessage.localizedCaseInsensitiveContains(substring), !capture.isProcessing {
        return
      }
      try? await Task.sleep(for: .milliseconds(25))
    }
    Issue.record("Expected status containing \"\(substring)\", got \"\(capture.statusMessage)\"")
  }

  private func waitForHistoryCount(
    _ history: HistoryViewModel,
    greaterThan count: Int
  ) async {
    for _ in 0..<200 {
      if history.history.count > count, !history.profiles.isEmpty {
        return
      }
      try? await Task.sleep(for: .milliseconds(25))
    }
    Issue.record("Expected history count > \(count), got \(history.history.count)")
  }
}
