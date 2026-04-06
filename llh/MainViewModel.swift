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
    let createdAt: Date
    let image: NSImage?

    init(id: UUID = UUID(), text: String, createdAt: Date = Date(), image: NSImage? = nil) {
        self.id = id
        self.text = text
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
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        image = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct LearningProfile: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    var history: [CapturedTextEntry]
    var selectedEntryID: CapturedTextEntry.ID?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        history: [CapturedTextEntry] = [],
        selectedEntryID: CapturedTextEntry.ID? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.history = history
        self.selectedEntryID = selectedEntryID
    }
}

@MainActor
final class MainViewModel: ObservableObject {
    @Published var recognizedText = ""
    @Published var capturedImage: NSImage?
    @Published var statusMessage = "Нажмите shortcut и выделите область."
    @Published var showPermissionHelp = false
    @Published var isProcessing = false
    @Published private(set) var profiles: [LearningProfile] = []
    @Published var selectedProfileID: LearningProfile.ID?
    @Published var selectedEntryID: CapturedTextEntry.ID?

    private let permissionService = ScreenRecordingPermissionService()
    private let regionSelectionService = RegionSelectionService()
    private let screenshotService = ScreenshotService()
    private let ocrService = OCRService()
    private let historyPersistenceService = HistoryPersistenceService()

    init() {
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.startCaptureFlow()
            }
        }
        loadHistory()
        refreshPermissionState()
    }

    func triggerCapture() {
        Task {
            await startCaptureFlow()
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

    func copyRecognizedText() {
        guard !recognizedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recognizedText, forType: .string)
        statusMessage = "Текст скопирован в буфер обмена."
    }

    func clearText() {
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return }
        profiles[profileIndex].history[entryIndex].text = ""
        recognizedText = ""
        profiles[profileIndex].selectedEntryID = selectedEntryID
        persistHistory()
        statusMessage = "Текст текущей записи очищен."
    }

    func createProfile(named rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Новый профиль" : trimmed
        let profile = LearningProfile(name: name)
        profiles.insert(profile, at: 0)
        selectProfile(profile.id)
        persistHistory()
        statusMessage = "Профиль \"\(name)\" создан."
    }

    func selectProfile(_ id: LearningProfile.ID?) {
        selectedProfileID = id
        syncProfileSelectionToEditor()
    }

    func deleteSelectedProfile() {
        guard let currentProfileID = selectedProfileID,
              let profileIndex = profiles.firstIndex(where: { $0.id == currentProfileID }) else { return }
        let removedName = profiles[profileIndex].name
        profiles.remove(at: profileIndex)

        if profiles.isEmpty {
            let defaultProfile = LearningProfile(name: "Основной")
            profiles = [defaultProfile]
            selectedProfileID = defaultProfile.id
        } else if let firstID = profiles.first?.id {
            selectedProfileID = firstID
        }

        syncProfileSelectionToEditor()
        persistHistory()
        statusMessage = "Профиль \"\(removedName)\" удален."
    }

    var canDeleteSelectedProfile: Bool {
        profiles.count > 1 && selectedProfileID != nil
    }

    var history: [CapturedTextEntry] {
        guard let selectedProfileIndex else { return [] }
        return profiles[selectedProfileIndex].history
    }

    var selectedProfileName: String {
        activeProfile?.name ?? "Профиль"
    }

    func selectEntry(_ id: CapturedTextEntry.ID?) {
        selectedEntryID = id
        if let selectedProfileIndex {
            profiles[selectedProfileIndex].selectedEntryID = id
        }
        syncSelectionToEditor()
    }

    func updateSelectedText(_ newText: String) {
        recognizedText = newText
        guard let profileIndex = selectedProfileIndex, let entryIndex = selectedEntryIndex else { return }
        profiles[profileIndex].history[entryIndex].text = newText
        profiles[profileIndex].selectedEntryID = selectedEntryID
        persistHistory()
    }

    func formattedDate(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
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

    private func startCaptureFlow() async {
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

            let text = try await ocrService.recognizeText(in: image)
            guard !text.isEmpty else {
                recognizedText = ""
                statusMessage = "Текст не найден."
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
            statusMessage = "Готово. Запись добавлена в историю."
        } catch RegionSelectionService.SelectionError.cancelled {
            statusMessage = "Выделение отменено."
        } catch {
            statusMessage = "Ошибка: \(error.localizedDescription)"
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
            capturedImage = nil
            return
        }
        recognizedText = profiles[profileIndex].history[entryIndex].text
        capturedImage = profiles[profileIndex].history[entryIndex].image
    }

    private func syncProfileSelectionToEditor() {
        guard let selectedProfileIndex else {
            selectedEntryID = nil
            recognizedText = ""
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
            let store = try historyPersistenceService.loadStore()
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
}
