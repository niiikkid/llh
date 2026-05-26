//
//  RefactorBaselineInventory.swift
//  llh
//
//  Phase 0 baseline map for incremental refactoring. Locked by RefactorBaselineTests.
//

import Foundation

/// Snapshot of `MainViewModel` surface area and orchestration boundaries before Phase 1.
enum RefactorBaselineInventory {
  enum FeatureBucket: String, CaseIterable {
    case capture
    case ocr
    case translationAndFormatting
    case history
    case profiles
    case settings
    case overlay
    case shortcuts
    case studyMaterial
    case sessionReading
  }

  /// `@Published` properties on `MainViewModel` (inventory count for regression detection).
  static let mainViewModelPublishedPropertyNames: [String] = []

  /// `@Published` properties on `EditorViewModel` (Phase 4 editor/format extraction).
  static let editorViewModelPublishedPropertyNames: [String] = [
    "recognizedText",
    "formattedRecognizedText",
    "capturedImage",
    "isFormattingRecognizedText",
    "statusMessage",
  ]

  /// `@Published` properties on `StudyViewModel` (Phase 4 study extraction).
  static let studyViewModelPublishedPropertyNames: [String] = [
    "studyMaterials",
    "statusMessage",
  ]

  /// `@Published` properties on `CaptureViewModel` (Phase 4 capture extraction).
  static let captureViewModelPublishedPropertyNames: [String] = [
    "isProcessing",
    "showPermissionHelp",
    "permissionStatus",
    "statusMessage",
  ]

  /// `@Published` properties on `HistoryViewModel` (Phase 4 history extraction).
  static let historyViewModelPublishedPropertyNames: [String] = [
    "profiles",
    "selectedProfileID",
    "selectedEntryID",
    "showsSessionReadingOverview",
    "statusMessage",
  ]

  /// `@Published` properties on `SettingsViewModel` (Phase 4 settings extraction).
  static let settingsViewModelPublishedPropertyNames: [String] = [
    "availableOpenAIModels",
    "selectedOpenAIModelID",
    "selectedOCREngine",
    "defaultNewProfileLearningLanguage",
    "translationOverlayMinimumDuration",
    "translationOverlaySecondsPerWord",
    "isLoadingOpenAIModels",
    "statusMessage",
  ]

  /// Public actions on `MainViewModel` grouped by feature bucket.
  static let publicActionsByBucket: [FeatureBucket: [String]] = [
    .capture: [],
    .ocr: [],
    .translationAndFormatting: [],
    .history: [],
    .profiles: [],
    .settings: [],
    .overlay: [
      "closeTranslationOverlay",
      "toggleLastTranslationOverlay",
    ],
    .shortcuts: [],
    .studyMaterial: [],
    .sessionReading: [],
  ]

  /// Public actions on `CaptureViewModel` (Phase 4).
  static let captureViewModelPublicActions: [String] = [
    "triggerCapture",
    "triggerCaptureFromHotkey",
    "refreshPermissionState",
    "openSystemSettings",
  ]

  /// Public actions on `HistoryViewModel` (Phase 4).
  static let historyViewModelPublicActions: [String] = [
    "deleteSelectedEntry",
    "selectEntry",
    "createProfile",
    "selectProfile",
    "deleteSelectedProfile",
    "copySessionReadingOverviewToPasteboard",
    "toggleSessionReadingOverview",
    "formattedDate",
  ]

  /// Where `persistHistory()` is invoked from `MainViewModel` (user vs automatic workflow).
  enum HistoryPersistenceTrigger: String, CaseIterable {
    case userDeleteEntry
    case userCreateProfile
    case userDeleteProfile
    case userEditEntryText
    case captureInsertedEntry
    case formatStarted
    case formatSucceeded
    case formatFailed
    case wordStudyStarted
    case wordStudySucceeded
    case wordStudyFailed
  }

  /// OpenAI operations reachable from app code and their prompt entry points.
  enum OpenAICallSite: String, CaseIterable {
    case fetchModels
    case recognizeTextInImage
    case formatRecognizedText
    case buildWordsStudyData
    case buildPhrasesStudyData
    case buildGrammarStudyData
  }

  static let openAIPromptBuilders: [OpenAICallSite: String] = [
    .formatRecognizedText: "OpenAIPromptBuilder.formatRecognizedTextSystemPrompt/UserPrompt",
    .recognizeTextInImage: "OpenAIPromptBuilder.recognizeTextInImageUserPrompt",
    .buildWordsStudyData: "OpenAIPromptBuilder.wordsAnalysisPrompt(for:)",
    .buildPhrasesStudyData: "OpenAIPromptBuilder.phrasesStudySystem/UserPrompt",
    .buildGrammarStudyData: "OpenAIPromptBuilder.grammarStudySystem/UserPrompt",
    .fetchModels: "GET /v1/models (no prompt)",
  ]

  /// APIs present on `OpenAIService` but not wired from `MainViewModel` / UI (Phase 0 finding).
  static let unwiredOpenAIStudyAPIs: [String] = [
    "buildPhrasesStudyData",
    "buildGrammarStudyData",
  ]

  /// Public actions on `TranslationOverlayCoordinator` (Phase 4).
  static let translationOverlayCoordinatorPublicActions: [String] = [
    "close",
    "toggleLastTranslation",
    "clearAwaitingFormattedEntry",
    "markEntryAwaitingFormattedResult",
    "handleFormattingPreflightFailure",
    "handleFormattingSuccess",
    "handleFormattingFailure",
  ]

  /// Public actions on `EditorViewModel` (Phase 4).
  static let editorViewModelPublicActions: [String] = [
    "updateSelectedText",
    "retryFormattingForSelectedEntry",
  ]

  /// Public actions on `StudyViewModel` (Phase 4).
  static let studyViewModelPublicActions: [String] = [
    "retryStudyAssistantDataForSelectedEntry",
  ]

  /// Public actions on `SettingsViewModel` (Phase 4).
  static let settingsViewModelPublicActions: [String] = [
    "validateAndSaveOpenAIToken",
    "refreshOpenAIModels",
    "deleteOpenAIToken",
    "selectOpenAIModel",
    "selectOCREngine",
    "switchToNextOCREngine",
    "setDefaultNewProfileLearningLanguage",
    "setTranslationOverlayMinimumDuration",
    "setTranslationOverlaySecondsPerWord",
  ]

  /// SwiftUI / App entry points that hold or observe `MainViewModel`.
  static let mainViewModelUIConsumers: [String] = [
    "llhApp (StateObject owner)",
    "Presentation/Main/ContentView",
    "MenuBarPanelView",
    "SettingsView (via MainViewModel.settings)",
    "HistoryView (via MainViewModel.history)",
    "Capture permission UI (via MainViewModel.capture)",
    "MenuBarPanelView (via MainViewModel.capture.triggerCapture)",
  ]
}
