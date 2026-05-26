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
    func sessionListLines_useFormattedSourceAndRussianWhenAvailable() {
        let formatted = StructuredFormattedText(
            cleanedText: "Hello world",
            pinyinText: "should not show for english",
            russianTranslation: "Привет мир"
        )
        let entry = CapturedTextEntry(
            text: "raw noisy hello",
            formattedText: formatted,
            formattingStatus: .succeeded
        )

        #expect(entry.sessionListTitleLine(learningLanguage: .english) == "Hello world")
        #expect(entry.sessionListPreviewLine() == "Привет мир")
    }

    @Test
    func sessionListLines_chineseSessionShowsPinyinInTitle() {
        let formatted = StructuredFormattedText(
            cleanedText: "你好",
            pinyinText: "nǐ hǎo",
            russianTranslation: "привет"
        )
        let entry = CapturedTextEntry(
            text: "你好",
            formattedText: formatted,
            formattingStatus: .succeeded
        )

        #expect(entry.sessionListTitleLine(learningLanguage: .chinese) == "nǐ hǎo")
        #expect(entry.sessionListPreviewLine() == "привет")
    }

    @Test
    func sessionListLines_autoSessionUsesPinyinWhenPresent() {
        let formatted = StructuredFormattedText(
            cleanedText: "你好",
            pinyinText: "ni hao",
            russianTranslation: "здравствуй"
        )
        let entry = CapturedTextEntry(
            text: "你好",
            formattedText: formatted,
            formattingStatus: .succeeded
        )

        #expect(entry.sessionListTitleLine(learningLanguage: .auto) == "ni hao")
    }

    @Test
    func sessionReadingLines_matchSessionSourceAndRussianTranslation() {
        let formatted = StructuredFormattedText(
            cleanedText: "你好",
            pinyinText: "nǐ hǎo",
            russianTranslation: "привет"
        )
        let entry = CapturedTextEntry(
            text: "你好",
            formattedText: formatted,
            formattingStatus: .succeeded
        )

        #expect(entry.sessionReadingSourceLine(learningLanguage: .chinese) == "nǐ hǎo")
        #expect(entry.sessionReadingTranslationLine() == "привет")
    }

    @Test
    func sessionReadingLines_englishUsesCleanedTextNotPinyin() {
        let formatted = StructuredFormattedText(
            cleanedText: "Hello",
            pinyinText: "ignored",
            russianTranslation: "Привет"
        )
        let entry = CapturedTextEntry(
            text: "raw",
            formattedText: formatted,
            formattingStatus: .succeeded
        )

        #expect(entry.sessionReadingSourceLine(learningLanguage: .english) == "Hello")
        #expect(entry.sessionReadingTranslationLine() == "Привет")
    }

    @Test
    func sessionReadingCopy_plainText_joinsBlocksWithBlankLineAndPlaceholders() {
        let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let items = [
            SessionReadingSequenceItem(id: id1, sourceLine: "Hello", translationLine: "Привет"),
            SessionReadingSequenceItem(id: id2, sourceLine: "", translationLine: "Только перевод"),
        ]
        let plain = MainViewModel.plainTextForSessionReadingCopy(items: items)
        let expected = """
        Hello
        Привет

        \(SessionReadingSequenceItem.missingSourcePlaceholder)
        Только перевод
        """
        #expect(plain == expected)
    }

    @Test
    func sessionListLines_fallsBackToRawWhenNoFormattedText() {
        let entry = CapturedTextEntry(text: "Line one\nLine two")

        #expect(entry.sessionListTitleLine(learningLanguage: .english) == "Line one")
        #expect(entry.sessionListPreviewLine().contains("Line one Line two"))
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
    func defaultProfile_hasAutoLanguageAndSystemKind() {
        let profile = LearningProfile.defaultProfile()

        #expect(profile.name == "Default")
        #expect(profile.learningLanguage == .auto)
        #expect(profile.isDefaultProfile)
    }

    @Test
    func historyPersistenceService_injectsDefaultProfileForExistingSnapshots() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = folderURL.appendingPathComponent("history.json", isDirectory: false)
        let service = HistoryPersistenceService(fileURL: fileURL)
        let sourceProfile = LearningProfile(
            name: "Spanish",
            learningLanguage: .spanish,
            history: [CapturedTextEntry(text: "Hola")],
            selectedEntryID: nil
        )
        let snapshot = HistoryStoreSnapshot(
            profiles: [sourceProfile],
            selectedProfileID: sourceProfile.id
        )

        try service.saveStore(snapshot)
        let loaded = try service.loadStore()

        #expect(loaded.profiles.count == 2)
        #expect(loaded.profiles.first?.isDefaultProfile == true)
        #expect(loaded.profiles.first?.learningLanguage == .auto)
        #expect(loaded.selectedProfileID == sourceProfile.id)
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

        #expect(store.translationOverlayMinimumDuration == 3)
        store.translationOverlayMinimumDuration = 7
        #expect(store.translationOverlayMinimumDuration == 7)
        store.translationOverlayMinimumDuration = 100
        #expect(store.translationOverlayMinimumDuration == 15)

        #expect(store.translationOverlaySecondsPerWord == 0.33)
        store.translationOverlaySecondsPerWord = 0.5
        #expect(store.translationOverlaySecondsPerWord == 0.5)
        store.translationOverlaySecondsPerWord = 10
        #expect(store.translationOverlaySecondsPerWord == 2)
    }

    @Test
    func translationOverlayTiming_usesWordCountWithMinimumDuration() {
        let formatted = StructuredFormattedText(
            cleanedText: "ni hao ma",
            pinyinText: "",
            russianTranslation: "привет как дела"
        )

        #expect(TranslationOverlayTiming.wordCount(in: [formatted.cleanedText, formatted.russianTranslation]) == 6)
        #expect(TranslationOverlayTiming.duration(for: formatted, minimumDuration: 3, secondsPerWord: 0.33) == 3)

        let longerFormatted = StructuredFormattedText(
            cleanedText: "one two three four five six seven eight nine ten",
            pinyinText: "",
            russianTranslation: ""
        )

        let longerDuration = TranslationOverlayTiming.duration(
            for: longerFormatted,
            minimumDuration: 3,
            secondsPerWord: 0.33
        )
        #expect(abs(longerDuration - 3.3) < 0.0001)

        let chineseFormatted = StructuredFormattedText(
            cleanedText: "你好 世界",
            pinyinText: "ni hao shi jie",
            russianTranslation: "привет мир"
        )
        #expect(TranslationOverlayTiming.visibleTexts(for: chineseFormatted) == ["ni hao shi jie", "привет мир"])
        #expect(TranslationOverlayTiming.wordCount(in: TranslationOverlayTiming.visibleTexts(for: chineseFormatted)) == 6)
    }

    @Test
    func latestTranslationLookup_returnsNewestFormattedTranslationAcrossProfiles() {
        let older = StructuredFormattedText(
            cleanedText: "hello",
            pinyinText: "",
            russianTranslation: "привет"
        )
        let newer = StructuredFormattedText(
            cleanedText: "good evening",
            pinyinText: "",
            russianTranslation: "добрый вечер"
        )

        let firstProfile = LearningProfile(
            name: "English",
            history: [
                CapturedTextEntry(
                    text: "hello",
                    formattedText: older,
                    formattingStatus: .succeeded,
                    createdAt: Date(timeIntervalSince1970: 100)
                )
            ]
        )
        let secondProfile = LearningProfile(
            name: "Spanish",
            learningLanguage: .spanish,
            history: [
                CapturedTextEntry(
                    text: "ignored",
                    formattedText: nil,
                    formattingStatus: .failed,
                    createdAt: Date(timeIntervalSince1970: 200)
                ),
                CapturedTextEntry(
                    text: "good evening",
                    formattedText: newer,
                    formattingStatus: .succeeded,
                    createdAt: Date(timeIntervalSince1970: 300)
                )
            ]
        )

        #expect(LatestTranslationLookup.latestFormattedText(in: [firstProfile, secondProfile]) == newer)
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
        let prompt = OpenAIPromptBuilder.wordsAnalysisPrompt(for: .chinese)
        let userPrompt = prompt.user("你好", "ni hao", "привет")

        #expect(prompt.system.contains("Never use hieroglyphs or source script in the response."))
        #expect(userPrompt.contains("Pronunciation:"))
        #expect(userPrompt.contains("Return short words or fixed short expressions, not full sentences."))
        #expect(userPrompt.contains("Prefer entries that are usually 1 to 3 characters long. Use 4 only for a natural fixed expression."))
        #expect(userPrompt.contains("If several characters form one word, keep them in one entry."))
        #expect(userPrompt.contains("explain each part separately in `character_breakdown`"))
    }

    @Test
    func openAIService_wordsAnalysisPrompt_usesSimplerRulesForNonChineseLanguages() {
        let prompt = OpenAIPromptBuilder.wordsAnalysisPrompt(for: .english)
        let userPrompt = prompt.user("hello world", "hello world", "привет мир")

        #expect(prompt.system.contains("Keep the target-language words in their original writing."))
        #expect(prompt.system.contains("`character_breakdown`: always an empty array"))
        #expect(!userPrompt.contains("Pronunciation:"))
        #expect(userPrompt.contains("Return words or short fixed expressions, not full sentences."))
        #expect(userPrompt.contains("Keep each entry exactly as written in the text."))
        #expect(userPrompt.contains("Always return `character_breakdown` as an empty array."))
    }

    @Test
    func wordStudyEntry_decodesWhenRussianPronunciationGuideKeyIsAbsent() throws {
        let json = Data(
            #"{"termPinyin":"hola","termTranslation":"привет","characterBreakdown":[]}"#.utf8
        )
        let decoded = try JSONDecoder().decode(WordStudyEntry.self, from: json)
        #expect(decoded.russianPronunciationGuide == "")
    }

    @Test
    func openAIService_wordsAnalysisPrompt_spanishIncludesRussianPronunciationGuide() {
        let prompt = OpenAIPromptBuilder.wordsAnalysisPrompt(for: .spanish)
        let userPrompt = prompt.user("Hola", "", "привет")

        #expect(prompt.system.contains("russian_pronunciation"))
        #expect(prompt.system.contains("Cyrillic"))
        #expect(userPrompt.contains("MUST fill `russian_pronunciation`"))
        #expect(prompt.system.contains("`character_breakdown`: always an empty array"))
    }

    @Test
    func learningLanguage_autoDisablesWordStudy() {
        #expect(LearningLanguage.auto.supportsWordStudy == false)
        #expect(LearningLanguage.english.supportsWordStudy == true)
    }

}
