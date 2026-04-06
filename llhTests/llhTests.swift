//
//  llhTests.swift
//  llhTests
//
//  Created by itsme on 06.04.2026.
//

import Testing
import Foundation
@testable import llh

struct llhTests {
    @Test
    func normalizeRecognizedLines_removesNoiseAndKeepsLineBreaks() {
        let input = [
            "  Hello world  ",
            "",
            "   ",
            "\nSecond line\n",
        ]

        let output = TextFormatter.normalizeRecognizedLines(input)
        #expect(output == "Hello world\nSecond line")
    }

    @Test
    func capturedTextEntry_buildsCompactTitleAndPreview() {
        let entry = CapturedTextEntry(
            text: """
                  First line title
                  Here goes another sentence for preview formatting.
                  """
        )

        #expect(entry.title == "First line title")
        #expect(entry.preview.contains("First line title Here goes another sentence"))
    }

    @Test
    func historyPersistenceService_savesAndLoadsHistory() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = folderURL.appendingPathComponent("history.json", isDirectory: false)
        let service = HistoryPersistenceService(fileURL: fileURL)
        let sourceProfile = LearningProfile(
            name: "Spanish",
            learningLanguage: .spanish,
            history: [
                CapturedTextEntry(text: "Hello"),
                CapturedTextEntry(text: "World")
            ],
            selectedEntryID: nil
        )
        let snapshot = HistoryStoreSnapshot(
            profiles: [sourceProfile],
            selectedProfileID: sourceProfile.id
        )

        try service.saveStore(snapshot)
        let loaded = try service.loadStore()

        #expect(loaded.profiles.count == 1)
        #expect(loaded.selectedProfileID == sourceProfile.id)
        #expect(loaded.profiles[0].name == "Spanish")
        #expect(loaded.profiles[0].learningLanguage == .spanish)
        #expect(loaded.profiles[0].history.map(\.text) == ["Hello", "World"])
        #expect(loaded.profiles[0].history[0].id == sourceProfile.history[0].id)
    }

    @Test
    func learningProfile_decodesLegacyPayloadWithoutLanguage() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "Legacy",
          "createdAt": "2026-04-06T12:00:00Z",
          "history": [],
          "selectedEntryID": null
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let profile = try decoder.decode(LearningProfile.self, from: Data(json.utf8))

        #expect(profile.name == "Legacy")
        #expect(profile.learningLanguage == .english)
    }

    @Test
    func learningProfile_deleteEntry_removesSelectedAndRepointsSelection() {
        let first = CapturedTextEntry(text: "First")
        let second = CapturedTextEntry(text: "Second")
        var profile = LearningProfile(
            name: "English",
            history: [first, second],
            selectedEntryID: first.id
        )

        let removed = profile.deleteEntry(with: first.id)

        #expect(removed == true)
        #expect(profile.history.count == 1)
        #expect(profile.history.first?.id == second.id)
        #expect(profile.selectedEntryID == second.id)
    }

    @Test
    @MainActor
    func openAISettingsStore_persistsSelectedModelID() {
        let suiteName = "llh.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var store = OpenAISettingsStore(
            userDefaults: defaults,
            selectedModelKey: "selected.model.test"
        )

        #expect(store.selectedModelID == nil)
        store.selectedModelID = "gpt-4.1-mini"
        #expect(store.selectedModelID == "gpt-4.1-mini")

        #expect(store.cachedModels.isEmpty)
        store.cachedModels = [
            OpenAIModel(id: "gpt-4.1-mini"),
            OpenAIModel(id: "gpt-4.1")
        ]
        #expect(store.cachedModels.map(\.id) == ["gpt-4.1-mini", "gpt-4.1"])

        #expect(store.selectedLearningLanguageRawValue == LearningLanguage.english.rawValue)
        store.selectedLearningLanguageRawValue = LearningLanguage.chinese.rawValue
        #expect(store.selectedLearningLanguageRawValue == LearningLanguage.chinese.rawValue)
    }

    @Test
    func capturedTextEntry_codableIncludesFormattingFields() throws {
        let entry = CapturedTextEntry(
            text: "ni hao 你好",
            formattedText: StructuredFormattedText(
                cleanedText: "你好",
                pinyinText: "ni hao",
                russianTranslation: "привет"
            ),
            formattingStatus: .succeeded,
            studyMaterials: StudyMaterials(
                words: WordStudyPayload(
                    entries: [
                        WordStudyEntry(
                            termPinyin: "ni hao",
                            termTranslation: "привет",
                            characterBreakdown: [
                                CharacterMeaning(pinyinText: "ni", russianTranslation: "ты"),
                                CharacterMeaning(pinyinText: "hao", russianTranslation: "хорошо")
                            ]
                        )
                    ]
                ),
                wordsStatus: .succeeded,
                phrases: PhraseStudyPayload(
                    entries: [
                        StudyListItem(pinyinText: "ni hao ma", russianTranslation: "как дела")
                    ]
                ),
                phrasesStatus: .succeeded,
                grammar: GrammarExplanationPayload(
                    structures: [
                        GrammarStructure(
                            title: "Вопрос с ma",
                            explanation: "Частица ma делает фразу вопросом.",
                            usageNotes: "Используется в простых вопросах да/нет.",
                            examples: [
                                GrammarExample(
                                    pinyinText: "ni hao ma",
                                    russianTranslation: "как дела"
                                )
                            ]
                        )
                    ]
                ),
                grammarStatus: .succeeded
            ),
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CapturedTextEntry.self, from: data)

        #expect(decoded.text == "ni hao 你好")
        #expect(decoded.formattedText?.cleanedText == "你好")
        #expect(decoded.formattedText?.pinyinText == "ni hao")
        #expect(decoded.formattedText?.russianTranslation == "привет")
        #expect(decoded.formattingStatus == .succeeded)
        #expect(decoded.studyMaterials.words?.entries.first?.termPinyin == "ni hao")
        #expect(decoded.studyMaterials.words?.entries.first?.characterBreakdown.count == 2)
        #expect(decoded.studyMaterials.phrases?.entries.first?.russianTranslation == "как дела")
        #expect(decoded.studyMaterials.grammar?.structures.first?.examples.count == 1)
        #expect(decoded.studyMaterials.grammarStatus == .succeeded)
    }

    @Test
    func openAIService_wordsAnalysisPrompt_keepsChineseBreakdownRules() {
        let prompt = OpenAIService.wordsAnalysisPrompt(for: .chinese)
        let userPrompt = prompt.user("你好", "ni hao", "привет")

        #expect(prompt.system.contains("Never use hieroglyphs or source script in the response."))
        #expect(userPrompt.contains("Pronunciation:"))
        #expect(userPrompt.contains("explain each part separately in `character_breakdown`"))
    }

    @Test
    func openAIService_wordsAnalysisPrompt_usesSimplerRulesForNonChineseLanguages() {
        let prompt = OpenAIService.wordsAnalysisPrompt(for: .english)
        let userPrompt = prompt.user("hello world", "hello world", "привет мир")

        #expect(prompt.system.contains("Keep the target-language words in their original writing."))
        #expect(prompt.system.contains("always return an empty array in `character_breakdown`"))
        #expect(!userPrompt.contains("Pronunciation:"))
        #expect(userPrompt.contains("keep the original word exactly as it appears in the target language text"))
        #expect(userPrompt.contains("return `character_breakdown` as an empty array"))
    }
}
