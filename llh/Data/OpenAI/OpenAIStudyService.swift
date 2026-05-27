//
//  OpenAIStudyService.swift
//  llh
//

import Foundation

/// Word and grammar study generation via Chat Completions (`POST /v1/chat/completions`).
struct OpenAIStudyService: Sendable {
    private let chatClient: OpenAIChatCompletionClient

    init(httpClient: OpenAIHTTPClient) {
        self.chatClient = OpenAIChatCompletionClient(httpClient: httpClient)
    }

    func buildWordsStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        let prompt = OpenAIPromptBuilder.wordsAnalysisPrompt(for: targetLanguage)
        let dto: WordsResponseDTO = try await chatClient.completeJSON(
            apiKey: apiKey,
            modelID: modelID,
            temperature: 0.2,
            systemPrompt: prompt.system,
            userPrompt: prompt.user(
                formattedText.cleanedText,
                formattedText.pinyinText,
                formattedText.russianTranslation
            )
        )
        let result = WordStudyPayload(
            entries: dto.entries.map {
                WordStudyEntry(
                    termPinyin: $0.termPinyin.trimmed,
                    termTranslation: $0.termTranslation.trimmed,
                    russianPronunciationGuide: ($0.russianPronunciation ?? "").trimmed,
                    characterBreakdown: $0.characterBreakdown.map {
                        CharacterMeaning(
                            pinyinText: $0.pinyinText.trimmed,
                            russianTranslation: $0.russianTranslation.trimmed
                        )
                    }
                )
            }
        )
        guard result.hasContent else { throw OpenAIServiceError.invalidStructuredResponse }
        return result
    }

    func buildGrammarStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> GrammarExplanationPayload {
        let dto: GrammarResponseDTO = try await chatClient.completeJSON(
            apiKey: apiKey,
            modelID: modelID,
            temperature: 0.2,
            systemPrompt: OpenAIPromptBuilder.grammarStudySystemPrompt(for: targetLanguage),
            userPrompt: OpenAIPromptBuilder.grammarStudyUserPrompt(
                targetLanguage: targetLanguage,
                formattedText: formattedText
            )
        )
        let result = GrammarExplanationPayload(
            structures: dto.structures.map {
                GrammarStructure(
                    title: $0.title.trimmed,
                    explanation: $0.explanation.trimmed,
                    usageNotes: $0.usageNotes.trimmed,
                    examples: $0.examples.map {
                        GrammarExample(
                            pinyinText: $0.pinyinText.trimmed,
                            russianTranslation: $0.russianTranslation.trimmed
                        )
                    }
                )
            }
        )
        guard result.hasContent else { throw OpenAIServiceError.invalidStructuredResponse }
        return result
    }
}

private struct StudyLineDTO: Decodable {
    let pinyinText: String
    let russianTranslation: String

    enum CodingKeys: String, CodingKey {
        case pinyinText = "pinyin_text"
        case russianTranslation = "russian_translation"
    }
}

private struct WordCharacterDTO: Decodable {
    let pinyinText: String
    let russianTranslation: String

    enum CodingKeys: String, CodingKey {
        case pinyinText = "pinyin_text"
        case russianTranslation = "russian_translation"
    }
}

private struct WordEntryDTO: Decodable {
    let termPinyin: String
    let termTranslation: String
    let russianPronunciation: String?
    let characterBreakdown: [WordCharacterDTO]

    enum CodingKeys: String, CodingKey {
        case termPinyin = "term_pinyin"
        case termTranslation = "term_translation"
        case russianPronunciation = "russian_pronunciation"
        case characterBreakdown = "character_breakdown"
    }
}

private struct WordsResponseDTO: Decodable {
    let entries: [WordEntryDTO]
}

private struct GrammarStructureDTO: Decodable {
    let title: String
    let explanation: String
    let usageNotes: String
    let examples: [StudyLineDTO]

    enum CodingKeys: String, CodingKey {
        case title
        case explanation
        case usageNotes = "usage_notes"
        case examples
    }
}

private struct GrammarResponseDTO: Decodable {
    let structures: [GrammarStructureDTO]
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
