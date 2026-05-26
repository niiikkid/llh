//
//  Phase2DomainModelsTests.swift
//  llhTests
//
//  Phase 2: domain models live outside MainViewModel.
//

import Foundation
import Testing
@testable import llh

struct Phase2DomainModelsTests {
  @Test
  func learningProfile_defaultProfile_usesAutoLanguageAndDefaultKind() {
    let profile = LearningProfile.defaultProfile()
    #expect(profile.kind == .default)
    #expect(profile.learningLanguage == .auto)
    #expect(profile.isDefaultProfile)
  }

  @Test
  func structuredFormattedText_sessionListSourceDisplay_prefersPinyinForChinese() {
    let formatted = StructuredFormattedText(
      cleanedText: "你好",
      pinyinText: "nǐ hǎo",
      russianTranslation: "привет"
    )
    #expect(formatted.sessionListSourceDisplay(learningLanguage: .chinese) == "nǐ hǎo")
  }

  @Test
  func openAIPromptBuilder_formatRecognizedTextUserPrompt_includesRawText() {
    let prompt = OpenAIPromptBuilder.formatRecognizedTextUserPrompt(
      targetLanguage: .chinese,
      rawText: "raw ocr"
    )
    #expect(prompt.contains("raw ocr"))
    #expect(prompt.contains("Chinese"))
  }

  @Test
  func historyStoreSnapshot_roundtripsThroughJSON() throws {
    let profile = LearningProfile.defaultProfile()
    let snapshot = HistoryStoreSnapshot(profiles: [profile], selectedProfileID: profile.id)
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(HistoryStoreSnapshot.self, from: data)
    #expect(decoded.profiles.count == 1)
    #expect(decoded.selectedProfileID == profile.id)
  }

  @Test
  func translationOverlayTiming_clampsMinimumDuration() {
    let formatted = StructuredFormattedText(cleanedText: "a", pinyinText: "", russianTranslation: "b")
    let duration = TranslationOverlayTiming.duration(
      for: formatted,
      minimumDuration: 0.5,
      secondsPerWord: 0.1
    )
    #expect(duration == 1)
  }
}
