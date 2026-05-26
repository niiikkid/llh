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
  static let mainViewModelPublishedPropertyNames: [String] = [
    "recognizedText",
    "formattedRecognizedText",
    "studyMaterials",
    "capturedImage",
    "statusMessage",
    "showPermissionHelp",
    "isProcessing",
    "profiles",
    "selectedProfileID",
    "selectedEntryID",
    "availableOpenAIModels",
    "selectedOpenAIModelID",
    "selectedOCREngine",
    "defaultNewProfileLearningLanguage",
    "translationOverlayMinimumDuration",
    "translationOverlaySecondsPerWord",
    "isLoadingOpenAIModels",
    "isFormattingRecognizedText",
    "showsSessionReadingOverview",
  ]

  /// Public actions on `MainViewModel` grouped by feature bucket.
  static let publicActionsByBucket: [FeatureBucket: [String]] = [
    .capture: [
      "triggerCapture",
      "refreshPermissionState",
      "openSystemSettings",
    ],
    .ocr: [
      "selectOCREngine",
      "switchToNextOCREngine",
    ],
    .translationAndFormatting: [
      "retryFormattingForSelectedEntry",
      "calculatedTranslationOverlayDuration",
    ],
    .history: [
      "deleteSelectedEntry",
      "selectEntry",
      "updateSelectedText",
    ],
    .profiles: [
      "createProfile",
      "selectProfile",
      "deleteSelectedProfile",
      "setDefaultNewProfileLearningLanguage",
    ],
    .settings: [
      "validateAndSaveOpenAIToken",
      "refreshOpenAIModels",
      "deleteOpenAIToken",
      "selectOpenAIModel",
      "setTranslationOverlayMinimumDuration",
      "setTranslationOverlaySecondsPerWord",
    ],
    .overlay: [
      "closeTranslationOverlay",
      "toggleLastTranslationOverlay",
    ],
    .shortcuts: [],
    .studyMaterial: [
      "retryStudyAssistantDataForSelectedEntry",
    ],
    .sessionReading: [
      "copySessionReadingOverviewToPasteboard",
      "toggleSessionReadingOverview",
      "plainTextForSessionReadingCopy",
      "formattedDate",
    ],
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
    .formatRecognizedText: "inline system/user messages in OpenAIService.formatRecognizedText",
    .recognizeTextInImage: "inline messages in OpenAIService.recognizeTextInImage",
    .buildWordsStudyData: "OpenAIService.wordsAnalysisPrompt(for:)",
    .buildPhrasesStudyData: "inline system/user in OpenAIService.buildPhrasesStudyData",
    .buildGrammarStudyData: "inline system/user in OpenAIService.buildGrammarStudyData",
    .fetchModels: "GET /v1/models (no prompt)",
  ]

  /// APIs present on `OpenAIService` but not wired from `MainViewModel` / UI (Phase 0 finding).
  static let unwiredOpenAIStudyAPIs: [String] = [
    "buildPhrasesStudyData",
    "buildGrammarStudyData",
  ]

  /// SwiftUI / App entry points that hold or observe `MainViewModel`.
  static let mainViewModelUIConsumers: [String] = [
    "llhApp (StateObject owner)",
    "ContentView",
    "MenuBarPanelView",
    "SettingsTabContainer",
    "OpenAISettingsTab",
    "OverlayTimingSettingsTab",
  ]
}
