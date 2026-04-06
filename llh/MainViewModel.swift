//
//  MainViewModel.swift
//  llh
//

import AppKit
import Combine
import Foundation
import KeyboardShortcuts

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
        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "Без текста" : firstLine
    }

    var preview: String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= 90 {
            return compact
        }
        return String(compact.prefix(90)) + "..."
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
                words: legacyData?.words.isEmpty == false ? WordStudyPayload(entries: legacyData?.words.map { WordStudyEntry(termPinyin: $0.pinyinText, termTranslation: $0.russianTranslation, characterBreakdown: []) } ?? []) : nil,
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
}

enum FormattingStatus: String, Codable {
    case notRequested
    case processing
    case succeeded
    case failed
}

enum LearningLanguage: String, CaseIterable, Identifiable, Codable {
    case auto
    case english
    case spanish
    case chinese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Автоопределение"
        case .english: return "Английский"
        case .spanish: return "Испанский"
        case .chinese: return "Китайский"
        }
    }

    var openAIInstructionName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .english: return "English"
        case .spanish: return "Spanish"
        case .chinese: return "Chinese"
        }
    }

    var formattingRules: String {
        switch self {
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

    var supportsWordStudy: Bool {
        self != .auto
    }
}

enum LearningProfileKind: String, Codable {
    case custom
    case `default`
}

enum OCREngine: String, CaseIterable, Identifiable {
    case local
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: return "Локально"
        case .ai: return "AI"
        }
    }
}

struct StructuredFormattedText: Equatable, Codable {
    let cleanedText: String
    let pinyinText: String
    let russianTranslation: String

    var hasContent: Bool {
        !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct StudyListItem: Equatable, Codable {
    let pinyinText: String
    let russianTranslation: String
}

struct CharacterMeaning: Equatable, Codable {
    let pinyinText: String
    let russianTranslation: String
}

struct WordStudyEntry: Equatable, Codable {
    let termPinyin: String
    let termTranslation: String
    let characterBreakdown: [CharacterMeaning]
}

struct WordStudyPayload: Equatable, Codable {
    let entries: [WordStudyEntry]

    var hasContent: Bool {
        !entries.isEmpty
    }
}

struct PhraseStudyPayload: Equatable, Codable {
    let entries: [StudyListItem]

    var hasContent: Bool {
        !entries.isEmpty
    }
}

struct GrammarExample: Equatable, Codable {
    let pinyinText: String
    let russianTranslation: String
}

struct GrammarStructure: Equatable, Codable {
    let title: String
    let explanation: String
    let usageNotes: String
    let examples: [GrammarExample]
}

struct GrammarExplanationPayload: Equatable, Codable {
    let structures: [GrammarStructure]

    var hasContent: Bool {
        !structures.isEmpty
    }
}

struct StudyAssistantData: Equatable, Codable {
    let words: [StudyListItem]
    let phrases: [StudyListItem]
    let grammar: LegacyGrammarExplanation

    var hasContent: Bool {
        !words.isEmpty || !phrases.isEmpty || !grammar.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct LegacyGrammarExplanation: Equatable, Codable {
    let summary: String
    let examples: [GrammarExample]
}

struct StudyMaterials: Equatable, Codable {
    var words: WordStudyPayload?
    var wordsStatus: FormattingStatus
    var phrases: PhraseStudyPayload?
    var phrasesStatus: FormattingStatus
    var grammar: GrammarExplanationPayload?
    var grammarStatus: FormattingStatus

    init(
        words: WordStudyPayload? = nil,
        wordsStatus: FormattingStatus = .notRequested,
        phrases: PhraseStudyPayload? = nil,
        phrasesStatus: FormattingStatus = .notRequested,
        grammar: GrammarExplanationPayload? = nil,
        grammarStatus: FormattingStatus = .notRequested
    ) {
        self.words = words
        self.wordsStatus = wordsStatus
        self.phrases = phrases
        self.phrasesStatus = phrasesStatus
        self.grammar = grammar
        self.grammarStatus = grammarStatus
    }
}

enum StudyAssistantTab: String, CaseIterable, Identifiable {
    case words

    var id: String { rawValue }

    var title: String {
        switch self {
        case .words: return "Слова"
        }
    }
}

struct LearningProfile: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var learningLanguage: LearningLanguage
    var kind: LearningProfileKind
    let createdAt: Date
    var history: [CapturedTextEntry]
    var selectedEntryID: CapturedTextEntry.ID?

    init(
        id: UUID = UUID(),
        name: String,
        learningLanguage: LearningLanguage = .english,
        kind: LearningProfileKind = .custom,
        createdAt: Date = Date(),
        history: [CapturedTextEntry] = [],
        selectedEntryID: CapturedTextEntry.ID? = nil
    ) {
        self.id = id
        self.name = name
        self.learningLanguage = learningLanguage
        self.kind = kind
        self.createdAt = createdAt
        self.history = history
        self.selectedEntryID = selectedEntryID
    }

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        history: [CapturedTextEntry] = [],
        selectedEntryID: CapturedTextEntry.ID? = nil
    ) {
        self.init(
            id: id,
            name: name,
            learningLanguage: .english,
            kind: .custom,
            createdAt: createdAt,
            history: history,
            selectedEntryID: selectedEntryID
        )
    }

    static func defaultProfile(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        history: [CapturedTextEntry] = [],
        selectedEntryID: CapturedTextEntry.ID? = nil
    ) -> LearningProfile {
        LearningProfile(
            id: id,
            name: "Default",
            learningLanguage: .auto,
            kind: .default,
            createdAt: createdAt,
            history: history,
            selectedEntryID: selectedEntryID
        )
    }

    var isDefaultProfile: Bool {
        kind == .default
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case learningLanguage
        case kind
        case createdAt
        case history
        case selectedEntryID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        learningLanguage = try container.decodeIfPresent(LearningLanguage.self, forKey: .learningLanguage) ?? .english
        kind = try container.decodeIfPresent(LearningProfileKind.self, forKey: .kind) ?? .custom
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        history = try container.decodeIfPresent([CapturedTextEntry].self, forKey: .history) ?? []
        selectedEntryID = try container.decodeIfPresent(CapturedTextEntry.ID.self, forKey: .selectedEntryID)
    }

    mutating func deleteEntry(with id: CapturedTextEntry.ID) -> Bool {
        guard let index = history.firstIndex(where: { $0.id == id }) else {
            return false
        }
        history.remove(at: index)
        selectedEntryID = history.first?.id
        return true
    }
}

@MainActor
final class MainViewModel: ObservableObject {
    private enum CaptureTriggerSource {
        case interface
        case hotkey
    }

    @Published var recognizedText = ""
    @Published var formattedRecognizedText: StructuredFormattedText?
    @Published var studyMaterials = StudyMaterials()
    @Published var selectedStudyAssistantTab: StudyAssistantTab = .words
    @Published var capturedImage: NSImage?
    @Published var statusMessage = "Нажмите shortcut и выделите область."
    @Published var showPermissionHelp = false
    @Published var isProcessing = false
    @Published private(set) var profiles: [LearningProfile] = []
    @Published var selectedProfileID: LearningProfile.ID?
    @Published var selectedEntryID: CapturedTextEntry.ID?
    @Published private(set) var availableOpenAIModels: [OpenAIModel] = []
    @Published var selectedOpenAIModelID: String?
    @Published var selectedOCREngine: OCREngine = .local
    @Published var defaultNewProfileLearningLanguage: LearningLanguage = .english
    @Published var translationOverlayDuration: Double = 5
    @Published private(set) var isLoadingOpenAIModels = false
    @Published private(set) var isFormattingRecognizedText = false

    private let permissionService = ScreenRecordingPermissionService()
    private let regionSelectionService = RegionSelectionService()
    private let screenshotService = ScreenshotService()
    private let ocrService = OCRService()
    private let historyPersistenceService = HistoryPersistenceService()
    private let openAIService = OpenAIService()
    private let translationOverlayService = TranslationOverlayService()
    private var openAISettingsStore = OpenAISettingsStore()
    private let openAITokenStore = KeychainOpenAITokenStore()
    private var overlayEntryAwaitingFormattedResult: CapturedTextEntry.ID?

    init() {
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.startCaptureFlow(triggeredBy: .hotkey)
            }
        }
        KeyboardShortcuts.onKeyUp(for: .switchOCREngine) { [weak self] in
            Task { @MainActor [weak self] in
                self?.switchToNextOCREngine(triggeredByHotkey: true)
            }
        }
        loadHistory()
        availableOpenAIModels = openAISettingsStore.cachedModels
        selectedOpenAIModelID = openAISettingsStore.selectedModelID
        selectedOCREngine = OCREngine(rawValue: openAISettingsStore.selectedOCREngineRawValue) ?? .local
        if selectedOpenAIModelID == nil {
            selectedOpenAIModelID = availableOpenAIModels.first?.id
        }
        defaultNewProfileLearningLanguage = LearningLanguage(rawValue: openAISettingsStore.selectedLearningLanguageRawValue) ?? .english
        translationOverlayDuration = openAISettingsStore.translationOverlayDuration
        refreshPermissionState()
    }

    var hasOpenAIToken: Bool {
        openAITokenStore.loadToken() != nil
    }

    func validateAndSaveOpenAIToken(_ token: String) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            statusMessage = "Введите OpenAI token."
            return
        }

        isLoadingOpenAIModels = true
        defer { isLoadingOpenAIModels = false }

        do {
            let models = try await openAIService.fetchModels(apiKey: trimmedToken)
            try openAITokenStore.saveToken(trimmedToken)
            availableOpenAIModels = models
            openAISettingsStore.cachedModels = models

            if let selectedOpenAIModelID,
               models.contains(where: { $0.id == selectedOpenAIModelID }) {
                // Keep current selection.
            } else {
                selectedOpenAIModelID = models.first?.id
            }
            openAISettingsStore.selectedModelID = selectedOpenAIModelID

            statusMessage = "Подключение к OpenAI успешно. Моделей: \(models.count)."
        } catch {
            statusMessage = "OpenAI: \(error.localizedDescription)"
        }
    }

    func refreshOpenAIModels() async {
        guard let token = openAITokenStore.loadToken() else {
            statusMessage = "Сначала сохраните OpenAI token."
            return
        }
        await validateAndSaveOpenAIToken(token)
    }

    func deleteOpenAIToken() {
        do {
            try openAITokenStore.deleteToken()
            statusMessage = "Токен OpenAI удален."
        } catch {
            statusMessage = "Не удалось удалить OpenAI token: \(error.localizedDescription)"
        }
    }

    func selectOpenAIModel(_ id: String?) {
        selectedOpenAIModelID = id
        openAISettingsStore.selectedModelID = id
        if let id {
            statusMessage = "Выбрана модель OpenAI: \(id)"
        }
    }

    func selectOCREngine(_ engine: OCREngine, showOverlay: Bool = false) {
        let previousEngine = selectedOCREngine
        selectedOCREngine = engine
        openAISettingsStore.selectedOCREngineRawValue = engine.rawValue
        statusMessage = "Движок распознавания: \(engine.title)."
        guard showOverlay, shouldUseCompactOverlay else { return }
        translationOverlayService.showMessage(
            title: previousEngine.title + " ->",
            subtitle: engine.title,
            duration: 1.5
        )
    }

    func switchToNextOCREngine(triggeredByHotkey: Bool = false) {
        guard let currentIndex = OCREngine.allCases.firstIndex(of: selectedOCREngine) else {
            selectOCREngine(.local, showOverlay: triggeredByHotkey)
            return
        }
        let nextIndex = OCREngine.allCases.index(after: currentIndex)
        let wrappedIndex = nextIndex == OCREngine.allCases.endIndex ? OCREngine.allCases.startIndex : nextIndex
        selectOCREngine(OCREngine.allCases[wrappedIndex], showOverlay: triggeredByHotkey)
    }

    func setDefaultNewProfileLearningLanguage(_ language: LearningLanguage) {
        defaultNewProfileLearningLanguage = language
        openAISettingsStore.selectedLearningLanguageRawValue = language.rawValue
    }

    func setTranslationOverlayDuration(_ duration: Double) {
        let clampedDuration = min(max(duration, 1), 15)
        translationOverlayDuration = clampedDuration
        openAISettingsStore.translationOverlayDuration = clampedDuration
    }

    var currentProfileLearningLanguage: LearningLanguage {
        activeProfile?.learningLanguage ?? defaultNewProfileLearningLanguage
    }

    var currentProfileSupportsWordStudy: Bool {
        currentProfileLearningLanguage.supportsWordStudy
    }

    func triggerCapture() {
        Task {
            await startCaptureFlow(triggeredBy: .interface)
        }
    }

    func refreshPermissionState() {
        let granted = permissionService.hasPermission
        showPermissionHelp = !granted
        if granted {
            statusMessage = "Готово к захвату."
        }
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }

    func deleteSelectedEntry() {
        guard let profileIndex = selectedProfileIndex, let selectedEntryID else { return }
        guard profiles[profileIndex].deleteEntry(with: selectedEntryID) else { return }
        self.selectedEntryID = profiles[profileIndex].selectedEntryID
        syncSelectionToEditor()
        persistHistory()
        statusMessage = "Перевод удален."
    }

    func createProfile(named rawName: String, learningLanguage: LearningLanguage) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Новый профиль" : trimmed
        let profile = LearningProfile(name: name, learningLanguage: learningLanguage)
        profiles.insert(profile, at: 0)
        setDefaultNewProfileLearningLanguage(learningLanguage)
        selectProfile(profile.id)
        persistHistory()
        statusMessage = "Профиль \"\(name)\" создан для языка \(learningLanguage.title.lowercased())."
    }

    func selectProfile(_ id: LearningProfile.ID?) {
        selectedProfileID = id
        syncProfileSelectionToEditor()
        if let activeProfile {
            statusMessage = "Выбрана история \"\(activeProfile.name)\" (\(activeProfile.learningLanguage.title.lowercased()))."
        }
    }

    func deleteSelectedProfile() {
        guard let currentProfileID = selectedProfileID,
              let profileIndex = profiles.firstIndex(where: { $0.id == currentProfileID }) else { return }
        guard !profiles[profileIndex].isDefaultProfile else {
            statusMessage = "Сессию Default удалить нельзя."
            return
        }
        let removedName = profiles[profileIndex].name
        profiles.remove(at: profileIndex)

        if let firstID = profiles.first?.id {
            selectedProfileID = firstID
        }

        syncProfileSelectionToEditor()
        persistHistory()
        statusMessage = "Профиль \"\(removedName)\" удален."
    }

    var canDeleteSelectedProfile: Bool {
        activeProfile?.isDefaultProfile == false
    }

    var history: [CapturedTextEntry] {
        guard let selectedProfileIndex else { return [] }
        return profiles[selectedProfileIndex].history
    }

    var selectedProfileName: String {
        activeProfile?.name ?? "Профиль"
    }

    var canDeleteSelectedEntry: Bool {
        selectedEntryIndex != nil
    }

    func selectEntry(_ id: CapturedTextEntry.ID?) {
        selectedEntryID = id
        if let selectedProfileIndex {
            profiles[selectedProfileIndex].selectedEntryID = id
        }
        selectedStudyAssistantTab = .words
        syncSelectionToEditor()
    }

    func updateSelectedText(_ newText: String) {
        recognizedText = newText
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return }
        profiles[profileIndex].history[entryIndex].text = newText
        profiles[profileIndex].history[entryIndex].formattedText = nil
        profiles[profileIndex].history[entryIndex].formattingStatus = .notRequested
        profiles[profileIndex].history[entryIndex].studyMaterials = StudyMaterials()
        formattedRecognizedText = nil
        studyMaterials = StudyMaterials()
        profiles[profileIndex].selectedEntryID = selectedEntryID
        persistHistory()
    }

    func retryFormattingForSelectedEntry() {
        guard let selectedEntryID else { return }
        Task {
            await formatEntryText(entryID: selectedEntryID, forceRetry: true)
        }
    }

    func formattedDate(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    func selectStudyAssistantTab(_ tab: StudyAssistantTab) {
        selectedStudyAssistantTab = tab
        guard let selectedEntryID else { return }
        Task {
            await loadStudyMaterial(for: selectedEntryID, tab: tab, forceReload: false)
        }
    }

    func retryStudyAssistantDataForSelectedEntry() {
        guard let selectedEntryID else { return }
        Task {
            await loadStudyMaterial(for: selectedEntryID, tab: selectedStudyAssistantTab, forceReload: true)
        }
    }

    private func ensureScreenRecordingPermission() -> Bool {
        if permissionService.hasPermission {
            showPermissionHelp = false
            return true
        }

        showPermissionHelp = true
        statusMessage = "Нет доступа к Screen Recording. Откройте System Settings и включите доступ."
        return false
    }

    private var shouldUseCompactOverlay: Bool {
        !NSApp.isActive
    }

    private func startCaptureFlow(triggeredBy source: CaptureTriggerSource) async {
        guard !isProcessing else { return }
        guard ensureScreenRecordingPermission() else { return }

        isProcessing = true
        statusMessage = "Выберите область на экране..."

        defer {
            isProcessing = false
        }

        do {
            let selectedRect = try await regionSelectionService.selectRegion()
            statusMessage = "Снимаю выделенную область..."

            let image = try await screenshotService.capture(region: selectedRect)
            capturedImage = NSImage(cgImage: image, size: .zero)
            statusMessage = "Распознаю текст..."

            let text = try await recognizeText(in: image)
            guard !text.isEmpty else {
                recognizedText = ""
                statusMessage = "Текст не найден."
                overlayEntryAwaitingFormattedResult = nil
                if source == .hotkey, shouldUseCompactOverlay {
                    translationOverlayService.showMessage(title: "Текст не найден", duration: 3)
                }
                return
            }

            let imagePreview = NSImage(cgImage: image, size: .zero)
            let entry = CapturedTextEntry(text: text, image: imagePreview)
            guard let selectedProfileIndex else { return }
            profiles[selectedProfileIndex].history.insert(entry, at: 0)
            profiles[selectedProfileIndex].selectedEntryID = entry.id
            selectedEntryID = entry.id
            syncSelectionToEditor()
            persistHistory()
            statusMessage = "Готово. Запись добавлена в историю. Форматирую текст..."
            if source == .hotkey, shouldUseCompactOverlay {
                overlayEntryAwaitingFormattedResult = entry.id
                translationOverlayService.showLoading()
            }
            await formatEntryText(entryID: entry.id, forceRetry: false)
        } catch RegionSelectionService.SelectionError.cancelled {
            statusMessage = "Выделение отменено."
            overlayEntryAwaitingFormattedResult = nil
            if source == .hotkey, shouldUseCompactOverlay {
                translationOverlayService.hide()
            }
        } catch {
            statusMessage = "Ошибка: \(error.localizedDescription)"
            overlayEntryAwaitingFormattedResult = nil
            if source == .hotkey, shouldUseCompactOverlay {
                translationOverlayService.showMessage(title: "Ошибка обработки", subtitle: error.localizedDescription, duration: 3)
            }
        }
    }

    private func recognizeText(in image: CGImage) async throws -> String {
        switch selectedOCREngine {
        case .local:
            return try await ocrService.recognizeText(in: image)
        case .ai:
            guard let token = openAITokenStore.loadToken() else {
                throw OpenAIServiceError.invalidTokenFormat
            }
            guard let modelID = selectedOpenAIModelID else {
                throw OpenAIServiceError.invalidResponse
            }
            return try await openAIService.recognizeTextInImage(
                apiKey: token,
                modelID: modelID,
                image: image
            )
        }
    }

    private var selectedEntryIndex: Int? {
        guard let selectedEntryID else { return nil }
        guard let selectedProfileIndex else { return nil }
        return profiles[selectedProfileIndex].history.firstIndex(where: { $0.id == selectedEntryID })
    }

    private var selectedProfileIndex: Int? {
        guard let selectedProfileID else { return nil }
        return profiles.firstIndex(where: { $0.id == selectedProfileID })
    }

    private var activeProfile: LearningProfile? {
        guard let selectedProfileIndex else { return nil }
        return profiles[selectedProfileIndex]
    }

    private func syncSelectionToEditor() {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else {
            recognizedText = ""
            formattedRecognizedText = nil
            studyMaterials = StudyMaterials()
            capturedImage = nil
            return
        }
        recognizedText = profiles[profileIndex].history[entryIndex].text
        formattedRecognizedText = profiles[profileIndex].history[entryIndex].formattedText
        studyMaterials = profiles[profileIndex].history[entryIndex].studyMaterials
        capturedImage = profiles[profileIndex].history[entryIndex].image
    }

    private func syncProfileSelectionToEditor() {
        guard let selectedProfileIndex else {
            selectedEntryID = nil
            recognizedText = ""
            formattedRecognizedText = nil
            studyMaterials = StudyMaterials()
            capturedImage = nil
            return
        }

        if let persistedSelection = profiles[selectedProfileIndex].selectedEntryID,
           profiles[selectedProfileIndex].history.contains(where: { $0.id == persistedSelection }) {
            selectedEntryID = persistedSelection
        } else {
            selectedEntryID = profiles[selectedProfileIndex].history.first?.id
            profiles[selectedProfileIndex].selectedEntryID = selectedEntryID
        }
        syncSelectionToEditor()
    }

    private func loadHistory() {
        do {
            var store = try historyPersistenceService.loadStore()
            store.profiles = store.profiles.map { profile in
                var mutableProfile = profile
                mutableProfile.history = mutableProfile.history.map { entry in
                    var mutableEntry = entry
                    if mutableEntry.formattedText?.hasContent == false {
                        mutableEntry.formattedText = nil
                    }
                    if mutableEntry.formattedText == nil, mutableEntry.formattingStatus == .processing {
                        mutableEntry.formattingStatus = .failed
                    }
                    if mutableEntry.formattedText != nil {
                        mutableEntry.formattingStatus = .succeeded
                    }
                    if mutableEntry.studyMaterials.words?.hasContent == false { mutableEntry.studyMaterials.words = nil }
                    if mutableEntry.studyMaterials.phrases?.hasContent == false { mutableEntry.studyMaterials.phrases = nil }
                    if mutableEntry.studyMaterials.grammar?.hasContent == false { mutableEntry.studyMaterials.grammar = nil }
                    if mutableEntry.studyMaterials.words == nil, mutableEntry.studyMaterials.wordsStatus == .processing {
                        mutableEntry.studyMaterials.wordsStatus = .failed
                    }
                    if mutableEntry.studyMaterials.phrases == nil, mutableEntry.studyMaterials.phrasesStatus == .processing {
                        mutableEntry.studyMaterials.phrasesStatus = .failed
                    }
                    if mutableEntry.studyMaterials.grammar == nil, mutableEntry.studyMaterials.grammarStatus == .processing {
                        mutableEntry.studyMaterials.grammarStatus = .failed
                    }
                    return mutableEntry
                }
                return mutableProfile
            }
            if !store.profiles.contains(where: \.isDefaultProfile) {
                store.profiles.insert(.defaultProfile(), at: 0)
            }
            if let defaultIndex = store.profiles.firstIndex(where: \.isDefaultProfile), defaultIndex != 0 {
                let defaultProfile = store.profiles.remove(at: defaultIndex)
                store.profiles.insert(defaultProfile, at: 0)
            }
            profiles = store.profiles
            selectedProfileID = store.selectedProfileID
            if selectedProfileIndex == nil {
                selectedProfileID = profiles.first?.id
            }
            syncProfileSelectionToEditor()
        } catch {
            statusMessage = "Не удалось загрузить историю: \(error.localizedDescription)"
        }
    }

    private func persistHistory() {
        do {
            let store = HistoryStoreSnapshot(profiles: profiles, selectedProfileID: selectedProfileID)
            try historyPersistenceService.saveStore(store)
        } catch {
            statusMessage = "Не удалось сохранить историю: \(error.localizedDescription)"
        }
    }

    private func formatEntryText(entryID: CapturedTextEntry.ID, forceRetry: Bool) async {
        guard !isFormattingRecognizedText else { return }
        guard let token = openAITokenStore.loadToken() else {
            statusMessage = "Сначала сохраните OpenAI token."
            if overlayEntryAwaitingFormattedResult == entryID {
                translationOverlayService.showMessage(title: "Сначала сохраните OpenAI token", duration: 3)
                overlayEntryAwaitingFormattedResult = nil
            }
            return
        }
        guard let modelID = selectedOpenAIModelID else {
            statusMessage = "Выберите модель OpenAI."
            if overlayEntryAwaitingFormattedResult == entryID {
                translationOverlayService.showMessage(title: "Выберите модель OpenAI", duration: 3)
                overlayEntryAwaitingFormattedResult = nil
            }
            return
        }
        guard let profileIndex = selectedProfileIndex else { return }
        guard let entryIndex = profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else { return }

        let currentStatus = profiles[profileIndex].history[entryIndex].formattingStatus
        let currentFormattedText = profiles[profileIndex].history[entryIndex].formattedText
        if !forceRetry, currentStatus == .succeeded, currentFormattedText?.hasContent == true {
            return
        }
        if !forceRetry, currentStatus == .processing {
            return
        }

        let rawText = profiles[profileIndex].history[entryIndex].text
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isFormattingRecognizedText = true
        profiles[profileIndex].history[entryIndex].formattingStatus = .processing
        persistHistory()

        defer {
            isFormattingRecognizedText = false
        }

        do {
            let formatted = try await openAIService.formatRecognizedText(
                apiKey: token,
                modelID: modelID,
                targetLanguage: profiles[profileIndex].learningLanguage,
                rawText: rawText
            )

            guard let latestProfileIndex = selectedProfileIndex,
                  let latestEntryIndex = profiles[latestProfileIndex].history.firstIndex(where: { $0.id == entryID }) else {
                return
            }

            profiles[latestProfileIndex].history[latestEntryIndex].formattedText = formatted
            profiles[latestProfileIndex].history[latestEntryIndex].formattingStatus = .succeeded
            if selectedEntryID == entryID {
                formattedRecognizedText = formatted
            }
            persistHistory()
            statusMessage = "Форматирование завершено."
            if overlayEntryAwaitingFormattedResult == entryID {
                if shouldUseCompactOverlay {
                    translationOverlayService.showTranslation(formatted, duration: translationOverlayDuration)
                } else {
                    translationOverlayService.hide()
                }
                overlayEntryAwaitingFormattedResult = nil
            }
        } catch {
            guard let latestProfileIndex = selectedProfileIndex,
                  let latestEntryIndex = profiles[latestProfileIndex].history.firstIndex(where: { $0.id == entryID }) else {
                return
            }
            profiles[latestProfileIndex].history[latestEntryIndex].formattedText = nil
            profiles[latestProfileIndex].history[latestEntryIndex].formattingStatus = .failed
            if selectedEntryID == entryID {
                formattedRecognizedText = nil
            }
            persistHistory()
            statusMessage = "Не удалось отформатировать текст: \(error.localizedDescription)"
            if overlayEntryAwaitingFormattedResult == entryID {
                if shouldUseCompactOverlay {
                    translationOverlayService.showMessage(
                        title: "Не удалось получить перевод",
                        subtitle: error.localizedDescription,
                        duration: 3
                    )
                } else {
                    translationOverlayService.hide()
                }
                overlayEntryAwaitingFormattedResult = nil
            }
        }
    }

    private func loadStudyMaterial(for entryID: CapturedTextEntry.ID, tab: StudyAssistantTab, forceReload: Bool) async {
        guard currentProfileSupportsWordStudy else { return }
        guard let token = openAITokenStore.loadToken() else {
            statusMessage = "Сначала сохраните OpenAI token."
            return
        }
        guard let modelID = selectedOpenAIModelID else {
            statusMessage = "Выберите модель OpenAI."
            return
        }
        guard let profileIndex = selectedProfileIndex,
              let entryIndex = profiles[profileIndex].history.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        var entry = profiles[profileIndex].history[entryIndex]
        guard let formattedText = entry.formattedText, formattedText.hasContent else { return }
        switch tab {
        case .words:
            if !forceReload, entry.studyMaterials.wordsStatus == .succeeded, entry.studyMaterials.words?.hasContent == true { return }
            if !forceReload, entry.studyMaterials.wordsStatus == .processing { return }
            profiles[profileIndex].history[entryIndex].studyMaterials.wordsStatus = .processing
        }
        persistHistory()
        entry = profiles[profileIndex].history[entryIndex]

        do {
            switch tab {
            case .words:
                let result = try await openAIService.buildWordsStudyData(
                    apiKey: token,
                    modelID: modelID,
                    targetLanguage: profiles[profileIndex].learningLanguage,
                    formattedText: formattedText
                )
                guard let latestProfileIndex = selectedProfileIndex,
                      let latestEntryIndex = profiles[latestProfileIndex].history.firstIndex(where: { $0.id == entryID }) else { return }
                profiles[latestProfileIndex].history[latestEntryIndex].studyMaterials.words = result
                profiles[latestProfileIndex].history[latestEntryIndex].studyMaterials.wordsStatus = .succeeded
            }

            if selectedEntryID == entryID {
                studyMaterials = profiles[selectedProfileIndex!].history[profiles[selectedProfileIndex!].history.firstIndex(where: { $0.id == entryID })!].studyMaterials
            }
            persistHistory()
            statusMessage = "\(tab.title) готовы."
        } catch {
            guard let latestProfileIndex = selectedProfileIndex,
                  let latestEntryIndex = profiles[latestProfileIndex].history.firstIndex(where: { $0.id == entryID }) else {
                return
            }
            switch tab {
            case .words:
                profiles[latestProfileIndex].history[latestEntryIndex].studyMaterials.words = nil
                profiles[latestProfileIndex].history[latestEntryIndex].studyMaterials.wordsStatus = .failed
            }
            if selectedEntryID == entryID {
                studyMaterials = profiles[latestProfileIndex].history[latestEntryIndex].studyMaterials
            }
            persistHistory()
            statusMessage = "Не удалось получить \(tab.title.lowercased()): \(error.localizedDescription)"
        }
    }

    var canRetryFormatting: Bool {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return false }
        let entry = profiles[profileIndex].history[entryIndex]
        return entry.formattingStatus == .failed && (entry.formattedText?.hasContent ?? false) == false
    }

    var selectedEntryFormattingStatus: FormattingStatus? {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return nil }
        return profiles[profileIndex].history[entryIndex].formattingStatus
    }

    var selectedEntryStudyAssistantStatus: FormattingStatus? {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return nil }
        let materials = profiles[profileIndex].history[entryIndex].studyMaterials
        switch selectedStudyAssistantTab {
        case .words: return materials.wordsStatus
        }
    }

    var canRetryStudyAssistantData: Bool {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return false }
        let materials = profiles[profileIndex].history[entryIndex].studyMaterials
        switch selectedStudyAssistantTab {
        case .words: return materials.wordsStatus == .failed && (materials.words?.hasContent ?? false) == false
        }
    }
}
