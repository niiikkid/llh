//
//  OpenAIPromptBuilder.swift
//  llh
//

import Foundation

enum OpenAIPromptBuilder {
    static func openAIInstructionName(for language: LearningLanguage) -> String {
        switch language {
        case .auto: return "Auto-detect"
        case .english: return "English"
        case .spanish: return "Spanish"
        case .chinese: return "Chinese"
        }
    }

    static func formattingRules(for language: LearningLanguage) -> String {
        switch language {
        case .auto:
            return "Detect the main language automatically. Keep the meaningful source text, remove OCR noise, and if the text is Chinese provide pinyin."
        case .english:
            return "Keep only English text and punctuation from the source. Remove words in other languages."
        case .spanish:
            return "Keep only Spanish text and punctuation from the source. Remove words in other languages."
        case .chinese:
            return "Keep only Chinese characters and relevant punctuation from the source. Remove pinyin, latin text, and words in other languages."
        }
    }

    static func recognizeTextInImageUserPrompt() -> String {
        "Распознай текст на изображении. Верни только распознанный текст без пояснений и markdown."
    }

    static func formatRecognizedTextSystemPrompt() -> String {
        """
        You clean OCR text for language learning and return JSON only.
        Do not add any content that is absent in source except Russian translation.
        Keep original symbols exactly for kept source fragments.
        Remove noise and foreign language fragments.
        Output strict JSON object with exactly 3 string fields:
        cleaned_text
        pinyin_text
        russian_translation
        No markdown, no code fences, no extra keys.
        """
    }

    static func formatRecognizedTextUserPrompt(
        targetLanguage: LearningLanguage,
        rawText: String
    ) -> String {
        """
        Target language: \(openAIInstructionName(for: targetLanguage))
        Rules:
        \(formattingRules(for: targetLanguage))

        Additional rules:
        1) cleaned_text: cleaned meaningful source text after OCR cleanup.
        2) pinyin_text: if the cleaned_text is Chinese, provide pinyin for it; otherwise return empty string.
        \(pinyinTonePromptLine(for: targetLanguage))
        3) russian_translation: concise Russian translation of cleaned_text.
        4) If target language is Auto-detect, first detect the main language of the text and then apply the same rules.

        Raw OCR text:
        \(rawText)
        """
    }

    static func wordsAnalysisPrompt(
        for targetLanguage: LearningLanguage
    ) -> (system: String, user: (String, String, String) -> String) {
        if targetLanguage == .chinese {
            return (
                system: """
                You produce JSON only for word-by-word study.
                Never use Chinese characters (hanzi / 汉字), hieroglyphs, or source script in any JSON field.
                `term_pinyin` and every `character_breakdown.pinyin_text` MUST be Latin-letter pinyin with tone marks (example: nǐ, hǎo, nǐ hǎo). Never write 你, 好, 你好, or any other hanzi there.
                Use only pinyin (Latin letters plus tone marks) and Russian.
                When using pinyin, always include tone marks on every syllable. Never omit tones and never use toneless pinyin.
                Return JSON object with key `entries`.
                Each entry has `term_pinyin`, `term_translation`, and `character_breakdown`.
                Each `character_breakdown` item has `pinyin_text` and `russian_translation`.
                No markdown. No extra keys.
                """,
                user: { cleanedText, pinyinText, russianTranslation in
                    """
                    Target language: \(openAIInstructionName(for: targetLanguage))
                    Cleaned text:
                    \(cleanedText)

                    Pronunciation:
                    \(pinyinText)

                    Translation:
                    \(russianTranslation)

                    Extract useful study entries from the text.
                    Return short words or fixed short expressions, not full sentences.
                    Prefer entries that correspond to 1 to 3 source characters. Use 4 only for a natural fixed expression.
                    Include useful standalone words such as pronouns or particles.
                    If several source characters form one word, keep them in one entry as one pinyin term.
                    Write every `term_pinyin` and every `pinyin_text` strictly as pinyin, never as Chinese characters.
                    If an entry has multiple characters or meaningful parts, explain each part separately in `character_breakdown` using pinyin, not hanzi.
                    Keep the result compact.
                    """
                }
            )
        }

        if targetLanguage == .spanish {
            return (
                system: """
                You produce JSON only for word-by-word study.
                Keep Spanish words in original spelling (include accents: á, ñ, etc.).
                Return JSON object with key `entries`.
                Each entry has `term_pinyin`, `term_translation`, `russian_pronunciation`, and `character_breakdown`.
                - `term_pinyin`: the Spanish word or short fixed expression exactly as it appears in the cleaned text.
                - `term_translation`: concise Russian translation of the meaning.
                - `russian_pronunciation`: short hint IN RUSSIAN (Cyrillic) for how a Russian speaker should read this Spanish aloud—like phrasebook transcription, not IPA. Use familiar Russian letters and hyphens between syllables if helpful; mark stress with an acute accent on the vowel (e.g. ó) when it helps. Do not repeat the Spanish word here—only the reading guide.
                - `character_breakdown`: always an empty array
                No markdown. No extra keys.
                """,
                user: { cleanedText, _, russianTranslation in
                    """
                    Target language: \(openAIInstructionName(for: targetLanguage))
                    Cleaned text:
                    \(cleanedText)

                    Translation:
                    \(russianTranslation)

                    Extract useful study entries from the text.
                    Return words or short fixed expressions, not full sentences.
                    Keep each Spanish term exactly as written in the text.
                    For every entry you MUST fill `russian_pronunciation` with a Cyrillic reading guide for a Russian learner.
                    Always return `character_breakdown` as an empty array.
                    Keep the result compact.
                    """
                }
            )
        }

        return (
            system: """
            You produce JSON only for word-by-word study.
            Keep the target-language words in their original writing.
            Use Russian only for translations.
            Return JSON object with key `entries`.
            Each entry has `term_pinyin`, `term_translation`, and `character_breakdown`.
            For non-Chinese languages:
            - `term_pinyin`: original word or short expression
            - `term_translation`: concise Russian translation
            - `character_breakdown`: always an empty array
            No markdown. No extra keys.
            """,
            user: { cleanedText, _, russianTranslation in
                """
                Target language: \(openAIInstructionName(for: targetLanguage))
                Cleaned text:
                \(cleanedText)

                Translation:
                \(russianTranslation)

                Extract useful study entries from the text.
                Return words or short fixed expressions, not full sentences.
                Keep each entry exactly as written in the text.
                Do not split entries into parts.
                Always return `character_breakdown` as an empty array.
                Keep the result compact.
                """
            }
        )
    }

    static func pinyinTonePromptLine(for targetLanguage: LearningLanguage) -> String {
        guard targetLanguage == .chinese || targetLanguage == .auto else {
            return "2a) If pinyin_text is empty, return empty string."
        }

        return "2a) If pinyin is used, it must always include tone marks on every syllable. Never omit tones and never use toneless pinyin."
    }

    static func translationChatSystemPrompt(context: TranslationChatContext) -> String {
        var lines = [
            "You are a language-learning assistant in a compact macOS overlay.",
            "The user asks follow-up questions about the translation they just received.",
            "Answer in Russian unless the user explicitly asks for another language.",
            "Use only the provided translation context. If it is not enough, say so briefly.",
            "Be concise and practical. Do not invent words or grammar that are absent from the context.",
            "",
            "Full translation:",
            "Source text: \(context.cleanedText)"
        ]

        let trimmedPinyin = context.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPinyin.isEmpty {
            lines.append("Pronunciation: \(context.pinyinText)")
        }
        lines.append("Russian translation: \(context.russianTranslation)")
        lines.append("")

        if context.wordEntries.isEmpty {
            lines.append("Word-by-word translations: not available yet.")
        } else {
            lines.append("Word-by-word translations:")
            lines.append(contentsOf: context.wordEntries.map(wordStudyEntryPromptLine))
        }

        return lines.joined(separator: "\n")
    }

    static func wordStudyEntryPromptLine(_ entry: WordStudyEntry) -> String {
        var line = "- \(entry.termPinyin)"
        let pronunciation = entry.russianPronunciationGuide.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pronunciation.isEmpty {
            line += " (\(pronunciation))"
        }
        line += " — \(entry.termTranslation)"

        let parts = entry.characterBreakdown.compactMap { part -> String? in
            let pinyin = part.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
            let translation = part.russianTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pinyin.isEmpty || !translation.isEmpty else {
                return nil
            }
            if translation.isEmpty {
                return pinyin
            }
            if pinyin.isEmpty {
                return translation
            }
            return "\(pinyin) — \(translation)"
        }
        if !parts.isEmpty {
            line += "; parts: \(parts.joined(separator: "; "))"
        }
        return line
    }
}
