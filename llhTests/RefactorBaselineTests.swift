//
//  RefactorBaselineTests.swift
//  llhTests
//
//  Phase 0 characterization tests and inventory locks.
//

import Foundation
import Testing
@testable import llh

struct RefactorBaselineTests {
  // MARK: - Inventory locks

  @Test
  func inventory_mainViewModelPublishedPropertyCount_isStable() {
    #expect(RefactorBaselineInventory.mainViewModelPublishedPropertyNames.count == 0)
  }

  @Test
  func inventory_editorViewModelPublishedPropertyCount_isStable() {
    #expect(RefactorBaselineInventory.editorViewModelPublishedPropertyNames.count == 5)
  }

  @Test
  func inventory_studyViewModelPublishedPropertyCount_isStable() {
    #expect(RefactorBaselineInventory.studyViewModelPublishedPropertyNames.count == 2)
  }

  @Test
  func inventory_captureViewModelPublishedPropertyCount_isStable() {
    #expect(RefactorBaselineInventory.captureViewModelPublishedPropertyNames.count == 4)
  }

  @Test
  func inventory_historyViewModelPublishedPropertyCount_isStable() {
    #expect(RefactorBaselineInventory.historyViewModelPublishedPropertyNames.count == 5)
  }

  @Test
  func inventory_settingsViewModelPublishedPropertyCount_isStable() {
    #expect(RefactorBaselineInventory.settingsViewModelPublishedPropertyNames.count == 8)
  }

  @Test
  func inventory_documentsUnwiredPhraseAndGrammarStudyAPIs() {
    #expect(RefactorBaselineInventory.unwiredOpenAIStudyAPIs == [
      "buildPhrasesStudyData",
      "buildGrammarStudyData",
    ])
  }

  @Test
  func inventory_openAICallSites_coverAllOpenAIServingMethods() {
    #expect(RefactorBaselineInventory.OpenAICallSite.allCases.count == 6)
    #expect(RefactorBaselineInventory.openAIPromptBuilders[.buildWordsStudyData] == "OpenAIPromptBuilder.wordsAnalysisPrompt(for:)")
  }

  // MARK: - History persistence

  @Test
  func historyPersistenceService_roundtripsMultipleProfilesWithSelection() throws {
    let folderURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = folderURL.appendingPathComponent("history.json", isDirectory: false)
    let service = HistoryPersistenceService(fileURL: fileURL)
    let defaultProfile = LearningProfile.defaultProfile()
    let spanish = LearningProfile(
      name: "Spanish",
      learningLanguage: .spanish,
      history: [CapturedTextEntry(text: "Hola")],
      selectedEntryID: nil
    )
    let chinese = LearningProfile(
      name: "Chinese",
      learningLanguage: .chinese,
      history: [
        CapturedTextEntry(text: "你好"),
        CapturedTextEntry(text: "谢谢"),
      ],
      selectedEntryID: nil
    )
    let snapshot = HistoryStoreSnapshot(
      profiles: [defaultProfile, spanish, chinese],
      selectedProfileID: chinese.id
    )

    try service.saveStore(snapshot)
    let loaded = try service.loadStore()

    #expect(loaded.profiles.count == 3)
    #expect(loaded.selectedProfileID == chinese.id)
    #expect(loaded.profiles[2].name == "Chinese")
    #expect(loaded.profiles[2].history.map(\.text) == ["你好", "谢谢"])
    #expect(loaded.profiles[1].learningLanguage == .spanish)
  }

  @Test
  func historyPersistenceService_decodesLegacyHistoryOnlyJSONArray() throws {
    let folderURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = folderURL.appendingPathComponent("history.json", isDirectory: false)
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    let legacyJSON = """
    [
      {
        "id": "22222222-2222-2222-2222-222222222222",
        "text": "Legacy line",
        "createdAt": "2026-04-01T10:00:00Z"
      }
    ]
    """
    try legacyJSON.write(to: fileURL, atomically: true, encoding: .utf8)

    let service = HistoryPersistenceService(fileURL: fileURL)
    let loaded = try service.loadStore()

    #expect(loaded.profiles.count == 1)
    #expect(loaded.profiles[0].isDefaultProfile)
    #expect(loaded.profiles[0].history.count == 1)
    #expect(loaded.profiles[0].history[0].text == "Legacy line")
    #expect(loaded.profiles[0].history[0].id.uuidString == "22222222-2222-2222-2222-222222222222")
    #expect(loaded.selectedProfileID == loaded.profiles[0].id)
  }

  @Test
  func historyPersistenceService_ensuresDefaultProfileAtIndexZero() throws {
    let folderURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = folderURL.appendingPathComponent("history.json", isDirectory: false)
    let service = HistoryPersistenceService(fileURL: fileURL)
    let custom = LearningProfile(name: "Only custom", learningLanguage: .english)
    let snapshot = HistoryStoreSnapshot(profiles: [custom], selectedProfileID: custom.id)

    try service.saveStore(snapshot)
    let loaded = try service.loadStore()

    #expect(loaded.profiles.count == 2)
    #expect(loaded.profiles[0].isDefaultProfile)
    #expect(loaded.profiles[0].name == "Default")
    #expect(loaded.profiles[1].id == custom.id)
  }

  // MARK: - Load repair (interrupted processing)

  @Test
  func historyEntryLoadRepair_marksInterruptedFormattingAsFailed() {
    let entry = CapturedTextEntry(
      text: "raw",
      formattedText: nil,
      formattingStatus: .processing
    )

    let repaired = HistoryEntryLoadRepair.repair(entry)

    #expect(repaired.formattingStatus == .failed)
    #expect(repaired.formattedText == nil)
  }

  @Test
  func historyEntryLoadRepair_marksInterruptedWordStudyAsFailed() {
    var materials = StudyMaterials()
    materials.wordsStatus = .processing
    let entry = CapturedTextEntry(
      text: "你好",
      formattedText: StructuredFormattedText(
        cleanedText: "你好",
        pinyinText: "ni hao",
        russianTranslation: "привет"
      ),
      formattingStatus: .succeeded,
      studyMaterials: materials
    )

    let repaired = HistoryEntryLoadRepair.repair(entry)

    #expect(repaired.studyMaterials.wordsStatus == .failed)
    #expect(repaired.studyMaterials.words == nil)
    #expect(repaired.formattingStatus == .succeeded)
  }

  @Test
  func historyEntryLoadRepair_preservesSucceededFormattingAndClearsEmptyPayload() {
    let emptyFormatted = StructuredFormattedText(cleanedText: "  ", pinyinText: "", russianTranslation: "")
    let entry = CapturedTextEntry(
      text: "x",
      formattedText: emptyFormatted,
      formattingStatus: .processing
    )

    let repaired = HistoryEntryLoadRepair.repair(entry)

    #expect(repaired.formattedText == nil)
    #expect(repaired.formattingStatus == .failed)
  }

  @Test
  func historyEntryLoadRepair_normalizesSucceededWhenFormattedTextPresent() {
    let entry = CapturedTextEntry(
      text: "hello",
      formattedText: StructuredFormattedText(
        cleanedText: "hello",
        pinyinText: "",
        russianTranslation: "привет"
      ),
      formattingStatus: .processing
    )

    let repaired = HistoryEntryLoadRepair.repair(entry)

    #expect(repaired.formattingStatus == .succeeded)
    #expect(repaired.formattedText?.russianTranslation == "привет")
  }

  // MARK: - Settings persistence

  @Test
  func openAISettingsStore_persistsSelectedOCREngineRawValue() {
    let suiteName = "llh.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    var store = OpenAISettingsStore(
      userDefaults: defaults,
      selectedOCREngineKey: "ocr.engine.test"
    )

    #expect(store.selectedOCREngineRawValue == "local")
    store.selectedOCREngineRawValue = OCREngine.ai.rawValue
    #expect(store.selectedOCREngineRawValue == OCREngine.ai.rawValue)

    var reloaded = OpenAISettingsStore(
      userDefaults: defaults,
      selectedOCREngineKey: "ocr.engine.test"
    )
    #expect(reloaded.selectedOCREngineRawValue == OCREngine.ai.rawValue)
  }

  // MARK: - Prompt construction

  @Test
  func openAIPromptBuilder_formattingRules_areNonEmptyForAllCases() {
    for language in [LearningLanguage.auto, .english, .chinese, .spanish] {
      #expect(!OpenAIPromptBuilder.formattingRules(for: language).isEmpty)
      #expect(!OpenAIPromptBuilder.openAIInstructionName(for: language).isEmpty)
    }
  }

  @Test
  func openAIPromptBuilder_wordsAnalysisPrompt_chineseIncludesToneRules() {
    let prompt = OpenAIPromptBuilder.wordsAnalysisPrompt(for: .chinese)
    #expect(prompt.system.contains("tone"))
    #expect(prompt.system.contains("pinyin"))
  }

  // MARK: - User-visible errors

  @Test
  func openAIServiceError_localizedDescriptions_areNonEmptyRussianMessages() {
    let samples: [OpenAIServiceError] = [
      .invalidTokenFormat,
      .unauthorized,
      .rateLimited,
      .unexpectedStatusCode(500),
      .invalidResponse,
      .noModelsFound,
      .hostNotFound,
      .networkUnavailable,
      .emptyFormattedText,
      .invalidStructuredResponse,
      .invalidImageData,
      .emptyRecognizedText,
      .timeout,
      .cancelled,
    ]

    for error in samples {
      let description = error.localizedDescription
      #expect(!description.isEmpty)
      #expect(description.contains("OpenAI") || description.contains("токен") || description.contains("Токен") || description.contains("изображение") || description.contains("сетев") || description.contains("DNS") || description.contains("распознан"))
    }
  }
}
