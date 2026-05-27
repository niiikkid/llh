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
                Never use hieroglyphs or source script in the response.
                Use only pinyin/transliteration and Russian.
                When using pinyin, always include tone marks on every syllable.
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
                    Prefer entries that are usually 1 to 3 characters long. Use 4 only for a natural fixed expression.
                    Include useful standalone words such as pronouns or particles.
                    If several characters form one word, keep them in one entry.
                    If an entry has multiple characters or meaningful parts, explain each part separately in `character_breakdown`.
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

    static func grammarStudySystemPrompt(for targetLanguage: LearningLanguage) -> String {
        """
        You produce JSON only for grammar explanation aimed at a Russian-speaking learner.
        Never use hieroglyphs or source script in the response.
        Use only transliteration and Russian.
        \(pinyinTonePromptParagraph(for: targetLanguage))
        Tone: explain like to a curious 14-year-old who does not know school grammar terms.
        Never use linguistic jargon or “smart words” (for example: существительное, глагол, прилагательное,
        наречие, часть речи, падеж, время, согласование, субъект, предикат, конструкция, конъюнкция).
        Describe what happens in the sentence in plain, physical, lived language — who does what, what comes
        first, what the phrase feels like, why it reads with this meaning.
        Brevity is required: minimum words, maximum clarity.
        Return JSON object with key `structures`.
        Return at most 2 structures; prefer 1 unless two clearly different patterns matter.
        Each structure has:
        title
        explanation
        usage_notes
        examples
        `examples` is an array of objects with:
        pinyin_text
        russian_translation
        Limits per structure:
        - title: a few words in Russian
        - explanation: at most 2 short sentences (about 35 words total)
        - usage_notes: at most 1 short sentence, or empty string
        - examples: at most 1 brief example, or an empty array
        Do not restate the full translation or pad with generic grammar lectures.
        """
    }

    static func grammarStudyUserPrompt(
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) -> String {
        """
        Target language: \(openAIInstructionName(for: targetLanguage))
        Cleaned text:
        \(formattedText.cleanedText)

        Pronunciation:
        \(formattedText.pinyinText)

        Translation:
        \(formattedText.russianTranslation)

        In very simple Russian, briefly explain only what helps feel the sentence from the inside.
        No grammar terminology — only everyday words, as if talking to a smart teenager who never studied linguistics.
        Pick the single most useful point; add a second structure only if truly necessary.
        Skip obvious trivia, repetition, and long background.
        For each structure:
        - title: 2–5 words in Russian
        - explanation: max 2 short sentences — how the parts link and why the meaning arises
        - usage_notes: one short sentence or empty
        - examples: 0–1 mini example with transliteration only (no source script), only if it clarifies
        One structure is usually enough.
        """
    }

    static func pinyinTonePromptLine(for targetLanguage: LearningLanguage) -> String {
        guard targetLanguage == .chinese || targetLanguage == .auto else {
            return "2a) If pinyin_text is empty, return empty string."
        }

        return "2a) If pinyin is used, it must always include tone marks on every syllable. Never omit tones and never use toneless pinyin."
    }

    static func pinyinTonePromptParagraph(for targetLanguage: LearningLanguage) -> String {
        guard targetLanguage == .chinese || targetLanguage == .auto else {
            return "If transliteration is used, keep it readable and consistent."
        }

        return "If pinyin is used, it must always include tone marks on every syllable. Never omit tones and never use toneless pinyin."
    }
}
