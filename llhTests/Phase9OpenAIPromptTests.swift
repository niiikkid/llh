//
//  Phase9OpenAIPromptTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase9OpenAIPromptTests {
    @Test
    func recognizeTextInImageUserPrompt_isRussianOnlyInstruction() {
        let prompt = OpenAIPromptBuilder.recognizeTextInImageUserPrompt()
        #expect(prompt.contains("Распознай текст"))
        #expect(prompt.contains("без пояснений"))
    }

    @Test
    func formatRecognizedTextSystemPrompt_requiresStrictJSONFields() {
        let prompt = OpenAIPromptBuilder.formatRecognizedTextSystemPrompt()
        #expect(prompt.contains("cleaned_text"))
        #expect(prompt.contains("pinyin_text"))
        #expect(prompt.contains("russian_translation"))
        #expect(prompt.contains("No markdown"))
    }

    @Test
    func formattingRules_spanishRemovesForeignWords() {
        let rules = OpenAIPromptBuilder.formattingRules(for: .spanish)
        #expect(rules.contains("Spanish"))
        #expect(rules.contains("other languages"))
    }

    @Test
    func formattingRules_chineseRemovesLatinAndPinyinFromSource() {
        let rules = OpenAIPromptBuilder.formattingRules(for: .chinese)
        #expect(rules.contains("Chinese characters"))
        #expect(rules.contains("pinyin"))
    }

    @Test
    func pinyinTonePromptLine_requiresTonesForChineseAndAuto() {
        let chinese = OpenAIPromptBuilder.pinyinTonePromptLine(for: .chinese)
        let auto = OpenAIPromptBuilder.pinyinTonePromptLine(for: .auto)
        let english = OpenAIPromptBuilder.pinyinTonePromptLine(for: .english)

        #expect(chinese.contains("tone marks"))
        #expect(auto.contains("tone marks"))
        #expect(english.contains("empty string"))
    }

    @Test
    func phrasesStudyPrompts_includeFormattedTextFields() {
        let formatted = StructuredFormattedText(
            cleanedText: "你好",
            pinyinText: "nǐ hǎo",
            russianTranslation: "привет"
        )
        let system = OpenAIPromptBuilder.phrasesStudySystemPrompt(for: .chinese)
        let user = OpenAIPromptBuilder.phrasesStudyUserPrompt(
            targetLanguage: .chinese,
            formattedText: formatted
        )

        #expect(system.contains("entries"))
        #expect(system.contains("pinyin_text"))
        #expect(user.contains("你好"))
        #expect(user.contains("nǐ hǎo"))
        #expect(user.contains("привет"))
        #expect(user.contains("stable phrases"))
    }

    @Test
    func grammarStudyPrompts_requestStructuresWithExamples() {
        let formatted = StructuredFormattedText(
            cleanedText: "你好",
            pinyinText: "nǐ hǎo",
            russianTranslation: "привет"
        )
        let system = OpenAIPromptBuilder.grammarStudySystemPrompt(for: .chinese)
        let user = OpenAIPromptBuilder.grammarStudyUserPrompt(
            targetLanguage: .chinese,
            formattedText: formatted
        )

        #expect(system.contains("structures"))
        #expect(system.contains("usage_notes"))
        #expect(user.contains("grammar structures"))
        #expect(user.contains("transliteration only"))
    }
}
