//
//  HistoryViewModel.swift
//  llh
//

import AppKit
import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var profiles: [LearningProfile] = []
    @Published var selectedProfileID: LearningProfile.ID?
    @Published var selectedEntryID: CapturedTextEntry.ID?
    @Published private(set) var showsSessionReadingOverview = false
    @Published private(set) var statusMessage = ""

    private let manageHistoryUseCase: ManageHistoryUseCase
    private let manageProfilesUseCase: ManageProfilesUseCase
    private let defaultLearningLanguage: () -> LearningLanguage
    private var onSelectionChanged: () -> Void = {}
    private var onPersistDefaultLanguageForNewProfile: (LearningLanguage) -> Void = { _ in }

    init(
        manageHistoryUseCase: ManageHistoryUseCase,
        manageProfilesUseCase: ManageProfilesUseCase,
        defaultLearningLanguage: @escaping () -> LearningLanguage
    ) {
        self.manageHistoryUseCase = manageHistoryUseCase
        self.manageProfilesUseCase = manageProfilesUseCase
        self.defaultLearningLanguage = defaultLearningLanguage
    }

    func configureSelectionSync(_ onSelectionChanged: @escaping () -> Void) {
        self.onSelectionChanged = onSelectionChanged
    }

    func configureNewProfileLanguagePersistence(_ persist: @escaping (LearningLanguage) -> Void) {
        onPersistDefaultLanguageForNewProfile = persist
    }

    var session: HistorySessionState {
        HistorySessionState(
            profiles: profiles,
            selectedProfileID: selectedProfileID,
            selectedEntryID: selectedEntryID
        )
    }

    var selectedProfileIndex: Int? {
        session.selectedProfileIndex
    }

    var selectedEntryIndex: Int? {
        session.selectedEntryIndex
    }

    var activeProfile: LearningProfile? {
        guard let selectedProfileIndex else { return nil }
        return profiles[selectedProfileIndex]
    }

    var currentProfileLearningLanguage: LearningLanguage {
        activeProfile?.learningLanguage ?? defaultLearningLanguage()
    }

    var currentProfileSupportsWordStudy: Bool {
        currentProfileLearningLanguage.supportsWordStudy
    }

    var history: [CapturedTextEntry] {
        guard let selectedProfileIndex else { return [] }
        return profiles[selectedProfileIndex].history
    }

    var sessionReadingSequence: [SessionReadingSequenceItem] {
        guard let selectedProfileIndex else { return [] }
        let language = profiles[selectedProfileIndex].learningLanguage
        return profiles[selectedProfileIndex].history
            .sorted(by: { $0.createdAt < $1.createdAt })
            .map { entry in
                SessionReadingSequenceItem(entry: entry, learningLanguage: language)
            }
    }

    var sessionReadingOverviewPlainTextForCopy: String {
        Self.plainTextForSessionReadingCopy(items: sessionReadingSequence)
    }

    var selectedProfileDisplayName: String {
        activeProfile?.displayName ?? "Сессия"
    }

    var selectedProfileName: String {
        activeProfile?.name ?? "Профиль"
    }

    var canDeleteSelectedProfile: Bool {
        manageProfilesUseCase.canDeleteSelectedProfile(state: session)
    }

    func canDeleteProfile(id: LearningProfile.ID) -> Bool {
        manageProfilesUseCase.canDeleteProfile(state: session, profileID: id)
    }

    var canDeleteSelectedEntry: Bool {
        selectedEntryIndex != nil
    }

    func loadFromDisk() {
        do {
            var loaded = try manageHistoryUseCase.loadSession()
            manageHistoryUseCase.resolveEntrySelectionForSelectedProfile(state: &loaded)
            applySession(loaded)
            onSelectionChanged()
        } catch {
            publishStatus("Не удалось загрузить историю: \(error.localizedDescription)")
        }
    }

    func persist() {
        do {
            try manageHistoryUseCase.saveSession(session)
        } catch {
            publishStatus("Не удалось сохранить историю: \(error.localizedDescription)")
        }
    }

    func applySession(_ session: HistorySessionState) {
        profiles = session.profiles
        selectedProfileID = session.selectedProfileID
        selectedEntryID = session.selectedEntryID
    }

    @discardableResult
    func mutateEntry(
        profileID: LearningProfile.ID,
        entryID: CapturedTextEntry.ID,
        _ body: (inout CapturedTextEntry) -> Void
    ) -> Bool {
        var updated = session
        guard manageHistoryUseCase.mutateEntry(
            state: &updated,
            profileID: profileID,
            entryID: entryID,
            body
        ) else {
            return false
        }
        applySession(updated)
        return true
    }

    func insertEntry(profileIndex: Int, entry: CapturedTextEntry) {
        var updated = session
        manageHistoryUseCase.insertEntry(
            state: &updated,
            profileIndex: profileIndex,
            entry: entry
        )
        applySession(updated)
    }

    func deleteSelectedEntry() {
        guard let selectedEntryID else { return }
        var updated = session
        guard manageHistoryUseCase.deleteEntry(state: &updated, entryID: selectedEntryID) else { return }
        applySession(updated)
        onSelectionChanged()
        persist()
        publishStatus("Перевод удален.")
    }

    func createProfile(
        named rawName: String,
        learningLanguage: LearningLanguage,
        automaticallyLoadWords: Bool = false,
        showWordsInCompactOverlay: Bool = false
    ) {
        var updated = session
        let profile = manageProfilesUseCase.createProfile(
            state: &updated,
            named: rawName,
            learningLanguage: learningLanguage,
            automaticallyLoadWords: automaticallyLoadWords,
            showWordsInCompactOverlay: showWordsInCompactOverlay
        )
        onPersistDefaultLanguageForNewProfile(learningLanguage)
        applySession(updated)
        onSelectionChanged()
        persist()
        publishStatus("Сессия «\(profile.displayName)» создана для языка \(learningLanguage.title.lowercased()).")
    }

    func selectProfile(_ id: LearningProfile.ID?) {
        showsSessionReadingOverview = false
        var updated = session
        manageProfilesUseCase.selectProfile(state: &updated, profileID: id)
        applySession(updated)
        onSelectionChanged()
        if let activeProfile {
            publishStatus(
                "Выбрана сессия «\(activeProfile.displayName)» (\(activeProfile.learningLanguage.title.lowercased()))."
            )
        }
    }

    func renameProfile(id: LearningProfile.ID, named rawName: String) {
        var updated = session
        switch manageProfilesUseCase.renameProfile(state: &updated, profileID: id, named: rawName) {
        case .renamed(let displayName):
            applySession(updated)
            persist()
            publishStatus("Сессия переименована в «\(displayName)».")
        case .profileNotFound:
            break
        }
    }

    func updateSessionAutomation(
        profileID: LearningProfile.ID,
        automaticallyLoadWords: Bool,
        showWordsInCompactOverlay: Bool
    ) {
        var updated = session
        switch manageProfilesUseCase.updateSessionAutomation(
            state: &updated,
            profileID: profileID,
            automaticallyLoadWords: automaticallyLoadWords,
            showWordsInCompactOverlay: showWordsInCompactOverlay
        ) {
        case .updated:
            applySession(updated)
            persist()
            publishStatus("Настройки автозагрузки для сессии сохранены.")
        case .profileNotFound:
            break
        }
    }

    func deleteProfile(id: LearningProfile.ID) {
        var updated = session
        switch manageProfilesUseCase.deleteProfile(state: &updated, profileID: id) {
        case .deleted(let removedName):
            applySession(updated)
            onSelectionChanged()
            persist()
            publishStatus("Сессия «\(removedName)» удалена.")
        case .cannotDeleteDefaultProfile:
            publishStatus("Сессию по умолчанию удалить нельзя.")
        case .noSelectedProfile, .profileNotFound:
            break
        }
    }

    func deleteSelectedProfile() {
        guard let profileID = selectedProfileID else { return }
        deleteProfile(id: profileID)
    }

    func selectEntry(_ id: CapturedTextEntry.ID?) {
        showsSessionReadingOverview = false
        var updated = session
        manageHistoryUseCase.selectEntry(state: &updated, entryID: id)
        applySession(updated)
        onSelectionChanged()
    }

    @discardableResult
    func updateSelectedEntryText(_ newText: String) -> Bool {
        var updated = session
        guard manageHistoryUseCase.updateSelectedEntryText(state: &updated, newText: newText) else {
            return false
        }
        applySession(updated)
        persist()
        return true
    }

    func toggleSessionReadingOverview() {
        showsSessionReadingOverview.toggle()
    }

    func copySessionReadingOverviewToPasteboard() {
        let text = sessionReadingOverviewPlainTextForCopy
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func formattedDate(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func plainTextForSessionReadingCopy(items: [SessionReadingSequenceItem]) -> String {
        items
            .map { "\($0.displaySourceLine)\n\($0.displayTranslationLine)" }
            .joined(separator: "\n\n")
    }

    private func publishStatus(_ message: String) {
        statusMessage = message
    }
}
