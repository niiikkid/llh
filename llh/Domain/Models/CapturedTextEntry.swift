//
//  CapturedTextEntry.swift
//  llh
//

import AppKit
import Foundation

struct CapturedTextEntry: Identifiable, Equatable, Codable {
    let id: UUID
    var text: String
    var formattedText: StructuredFormattedText?
    var formattingStatus: FormattingStatus
    var studyMaterials: StudyMaterials
    let createdAt: Date
    let image: NSImage?

    init(
        id: UUID = UUID(),
        text: String,
        formattedText: StructuredFormattedText? = nil,
        formattingStatus: FormattingStatus = .notRequested,
        studyMaterials: StudyMaterials = StudyMaterials(),
        createdAt: Date = Date(),
        image: NSImage? = nil
    ) {
        self.id = id
        self.text = text
        self.formattedText = formattedText
        self.formattingStatus = formattingStatus
        self.studyMaterials = studyMaterials
        self.createdAt = createdAt
        self.image = image
    }

    var title: String {
        let firstLine = Self.firstLine(from: text)
        return firstLine.isEmpty ? "Без текста" : firstLine
    }

    var preview: String {
        Self.compactPreview(of: text)
    }

    /// Первая строка списка сессий: форматированный источник (с учётом языка сессии) или сырой текст.
    func sessionListTitleLine(learningLanguage: LearningLanguage) -> String {
        if let formatted = formattedText, formatted.hasContent {
            let display = formatted.sessionListSourceDisplay(learningLanguage: learningLanguage)
            let line = Self.firstLine(from: display)
            if !line.isEmpty {
                return line
            }
        }
        return title
    }

    /// Вторая строка: русский перевод из форматированного ответа или компактный сырой текст.
    func sessionListPreviewLine() -> String {
        if let formatted = formattedText,
           !formatted.russianTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Self.compactPreview(of: formatted.russianTranslation)
        }
        return preview
    }

    private static func firstLine(from text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func compactPreview(of text: String, maxCharacters: Int = 90) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= maxCharacters {
            return compact
        }
        return String(compact.prefix(maxCharacters)) + "..."
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case formattedText
        case formattingStatus
        case studyMaterials
        case studyAssistantData
        case studyAssistantStatus
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        if let structured = try container.decodeIfPresent(StructuredFormattedText.self, forKey: .formattedText) {
            formattedText = structured
        } else if let legacyFormatted = try container.decodeIfPresent(String.self, forKey: .formattedText) {
            let trimmed = legacyFormatted.trimmingCharacters(in: .whitespacesAndNewlines)
            formattedText = trimmed.isEmpty
                ? nil
                : StructuredFormattedText(cleanedText: trimmed, pinyinText: "", russianTranslation: "")
        } else {
            formattedText = nil
        }
        formattingStatus = try container.decodeIfPresent(FormattingStatus.self, forKey: .formattingStatus) ?? .notRequested
        if let materials = try container.decodeIfPresent(StudyMaterials.self, forKey: .studyMaterials) {
            studyMaterials = materials
        } else {
            let legacyData = try container.decodeIfPresent(StudyAssistantData.self, forKey: .studyAssistantData)
            let legacyStatus = try container.decodeIfPresent(FormattingStatus.self, forKey: .studyAssistantStatus) ?? .notRequested
            studyMaterials = StudyMaterials(
                words: legacyData?.words.isEmpty == false ? WordStudyPayload(entries: legacyData?.words.map { WordStudyEntry(termPinyin: $0.pinyinText, termTranslation: $0.russianTranslation, russianPronunciationGuide: "", characterBreakdown: []) } ?? []) : nil,
                wordsStatus: legacyData?.words.isEmpty == false ? .succeeded : legacyStatus,
                phrases: legacyData?.phrases.isEmpty == false ? PhraseStudyPayload(entries: legacyData?.phrases ?? []) : nil,
                phrasesStatus: legacyData?.phrases.isEmpty == false ? .succeeded : legacyStatus,
                grammar: {
                    guard let legacyData else { return nil }
                    return GrammarExplanationPayload(
                        structures: legacyData.grammar.summary.isEmpty && legacyData.grammar.examples.isEmpty
                            ? []
                            : [
                                GrammarStructure(
                                    title: "Грамматическая структура",
                                    explanation: legacyData.grammar.summary,
                                    usageNotes: "",
                                    examples: legacyData.grammar.examples
                                )
                            ]
                    )
                }(),
                grammarStatus: {
                    guard let legacyData else { return legacyStatus }
                    return legacyData.grammar.summary.isEmpty && legacyData.grammar.examples.isEmpty ? legacyStatus : .succeeded
                }()
            )
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        image = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(formattedText, forKey: .formattedText)
        try container.encode(formattingStatus, forKey: .formattingStatus)
        try container.encode(studyMaterials, forKey: .studyMaterials)
        try container.encode(createdAt, forKey: .createdAt)
    }

    /// Строка оригинала для просмотра «вся сессия»: для китайского и авто с пиньинем — пиньинь, иначе очищенный текст; без форматирования — сырой текст.
    func sessionReadingSourceLine(learningLanguage: LearningLanguage) -> String {
        if let formatted = formattedText, formatted.hasContent {
            return formatted.sessionListSourceDisplay(learningLanguage: learningLanguage)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Перевод для режима «вся сессия» (пусто, если форматирования ещё нет).
    func sessionReadingTranslationLine() -> String {
        guard let formatted = formattedText, formatted.hasContent else { return "" }
        return formatted.russianTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
