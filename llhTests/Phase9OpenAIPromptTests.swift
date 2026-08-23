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
    func wordsAnalysisPrompt_chineseRequiresPinyinNotHanzi() {
        let prompt = OpenAIPromptBuilder.wordsAnalysisPrompt(for: .chinese)
        let userPrompt = prompt.user("你好", "nǐ hǎo", "привет")

        #expect(prompt.system.contains("Latin-letter pinyin"))
        #expect(prompt.system.contains("Never write 你, 好, 你好"))
        #expect(userPrompt.contains("strictly as pinyin, never as Chinese characters"))
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
    func translationChatSystemPrompt_includesFullTranslationAndWords() {
        let context = TranslationChatContext(
            formattedText: StructuredFormattedText(
                cleanedText: "你好",
                pinyinText: "nǐ hǎo",
                russianTranslation: "привет"
            ),
            learningLanguage: .chinese,
            words: WordStudyPayload(entries: [
                WordStudyEntry(
                    termPinyin: "nǐ",
                    termTranslation: "ты",
                    russianPronunciationGuide: "ни",
                    characterBreakdown: [
                        CharacterMeaning(pinyinText: "nǐ", russianTranslation: "ты")
                    ]
                )
            ])
        )
        let prompt = OpenAIPromptBuilder.translationChatSystemPrompt(context: context)

        #expect(prompt.contains("Source text: 你好"))
        #expect(prompt.contains("Pronunciation: nǐ hǎo"))
        #expect(prompt.contains("Russian translation: привет"))
        #expect(prompt.contains("nǐ (ни) — ты"))
        #expect(prompt.contains("parts: nǐ — ты"))
        #expect(prompt.contains("Never use Chinese characters"))
        #expect(prompt.contains("pinyin with tone marks"))
        #expect(prompt.contains("Never write 你, 好, 你好"))
    }

    @Test
    func translationChatSystemPrompt_forbidsHanziOnlyForChinese() {
        let chinese = TranslationChatContext(
            formattedText: StructuredFormattedText(
                cleanedText: "你好",
                pinyinText: "nǐ hǎo",
                russianTranslation: "привет"
            ),
            learningLanguage: .chinese
        )
        let english = TranslationChatContext(
            formattedText: StructuredFormattedText(
                cleanedText: "hello",
                pinyinText: "",
                russianTranslation: "привет"
            ),
            learningLanguage: .english
        )

        #expect(chinese.forbidsHanziInReplies)
        #expect(!english.forbidsHanziInReplies)
        #expect(OpenAIPromptBuilder.translationChatSystemPrompt(context: chinese).contains("STRICT OUTPUT RULE for Chinese"))
        #expect(!OpenAIPromptBuilder.translationChatSystemPrompt(context: english).contains("STRICT OUTPUT RULE for Chinese"))
    }

    @Test
    func translationChatSystemPrompt_marksMissingWords() {
        let context = TranslationChatContext(
            formattedText: StructuredFormattedText(
                cleanedText: "hello",
                pinyinText: "",
                russianTranslation: "привет"
            )
        )
        let prompt = OpenAIPromptBuilder.translationChatSystemPrompt(context: context)

        #expect(prompt.contains("Word-by-word translations: not available yet."))
        #expect(!prompt.contains("Pronunciation:"))
    }

    @Test
    func structuredFormattedText_overlayPrimaryText_prefersPinyinThenCleanedThenRussian() {
        let withPinyin = StructuredFormattedText(
            cleanedText: "你好",
            pinyinText: "nǐ hǎo",
            russianTranslation: "привет"
        )
        #expect(withPinyin.overlayPrimaryText == "nǐ hǎo")

        let withoutPinyin = StructuredFormattedText(
            cleanedText: "hello",
            pinyinText: "",
            russianTranslation: "привет"
        )
        #expect(withoutPinyin.overlayPrimaryText == "hello")

        let russianOnly = StructuredFormattedText(
            cleanedText: "",
            pinyinText: "",
            russianTranslation: "привет"
        )
        #expect(russianOnly.overlayPrimaryText == "привет")
    }
}
