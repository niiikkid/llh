//
//  CompactOverlayChatViewModel.swift
//  llh
//

import Combine
import Foundation

struct CompactOverlayChatCredentials {
    var openAIAPIKey: () -> String?
    var textProvider: () -> AIProvider
    var textAPIKey: () -> String?
    var textModelID: () -> String?

    init(
        openAIAPIKey: @escaping () -> String?,
        textProvider: @escaping () -> AIProvider,
        textAPIKey: @escaping () -> String?,
        textModelID: @escaping () -> String?
    ) {
        self.openAIAPIKey = openAIAPIKey
        self.textProvider = textProvider
        self.textAPIKey = textAPIKey
        self.textModelID = textModelID
    }

    init(settings: SettingsViewModel) {
        self.init(
            openAIAPIKey: { [weak settings] in settings?.openAIAPIKey() },
            textProvider: { [weak settings] in settings?.selectedTextProvider ?? .openAI },
            textAPIKey: { [weak settings] in settings?.textAPIKey() },
            textModelID: { [weak settings] in settings?.textModelID() }
        )
    }
}

enum CompactOverlayVoicePhase: Equatable {
    case idle
    case recording
    case transcribing
    case draft
}

@MainActor
final class CompactOverlayChatViewModel: ObservableObject {
    @Published private(set) var voicePhase: CompactOverlayVoicePhase = .idle
    @Published var draftText = ""
    @Published private(set) var messages: [TranslationChatMessage] = []
    @Published private(set) var isChatPanelVisible = false
    @Published private(set) var isSending = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var context: TranslationChatContext?

    var onPresentationChange: (() -> Void)?

    private let recorder: any MicrophoneRecording
    private let transcribeUseCase: TranscribeSpeechUseCase
    private let chatUseCase: AskTranslationChatUseCase
    private let credentials: CompactOverlayChatCredentials
    private var recordingTimeoutTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var isStartingRecording = false

    static let maximumRecordingDuration: TimeInterval = 60

    init(
        recorder: any MicrophoneRecording,
        transcribeUseCase: TranscribeSpeechUseCase,
        chatUseCase: AskTranslationChatUseCase,
        credentials: CompactOverlayChatCredentials
    ) {
        self.recorder = recorder
        self.transcribeUseCase = transcribeUseCase
        self.chatUseCase = chatUseCase
        self.credentials = credentials
    }

    var isRecording: Bool {
        voicePhase == .recording
    }

    var isTranscribing: Bool {
        voicePhase == .transcribing
    }

    var hasDraft: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSend: Bool {
        hasDraft && !isSending && !isRecording && !isTranscribing
    }

    var wantsKeyFocus: Bool {
        isChatPanelVisible || voicePhase == .draft
    }

    func updateContext(_ context: TranslationChatContext) {
        self.context = context
    }

    func reset(context: TranslationChatContext?, announceChange: Bool = true) {
        cancelInFlightWork()
        recorder.cancelRecording()
        self.context = context
        voicePhase = .idle
        draftText = ""
        messages = []
        isChatPanelVisible = false
        isSending = false
        statusMessage = nil
        if announceChange {
            notifyPresentationChange()
        }
    }

    func closeChatPanel() {
        isChatPanelVisible = false
        notifyPresentationChange()
    }

    func handleMicTapped() {
        statusMessage = nil
        switch voicePhase {
        case .recording:
            stopRecordingAndTranscribe()
        case .transcribing:
            return
        case .idle, .draft:
            guard !isStartingRecording else { return }
            startRecording()
        }
    }

    func sendDraft() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSending else { return }

        guard let context else {
            statusMessage = CompactOverlayChatStrings.missingTranslationContext
            notifyPresentationChange()
            return
        }

        switch chatUseCase.preflight(
            apiKey: credentials.textAPIKey(),
            modelID: credentials.textModelID(),
            userText: text
        ) {
        case .missingAPIKey:
            statusMessage = CompactOverlayChatStrings.missingTextAPIKey
            notifyPresentationChange()
            return
        case .missingModel:
            statusMessage = CompactOverlayChatStrings.missingTextModel
            notifyPresentationChange()
            return
        case .emptyMessage:
            statusMessage = OpenAIServiceError.emptyChatMessage.localizedDescription
            notifyPresentationChange()
            return
        case .ready:
            break
        }

        guard let apiKey = credentials.textAPIKey(), let modelID = credentials.textModelID() else {
            return
        }

        let history = messages
        messages.append(TranslationChatMessage(role: .user, text: text))
        draftText = ""
        voicePhase = .idle
        isChatPanelVisible = true
        isSending = true
        statusMessage = nil
        notifyPresentationChange()

        sendTask?.cancel()
        sendTask = Task { [weak self] in
            guard let self else { return }
            do {
                let reply = try await self.chatUseCase.perform(
                    provider: self.credentials.textProvider(),
                    apiKey: apiKey,
                    modelID: modelID,
                    context: context,
                    history: history,
                    userText: text
                )
                guard !Task.isCancelled else { return }
                self.messages.append(TranslationChatMessage(role: .assistant, text: reply))
                self.isSending = false
                self.notifyPresentationChange()
            } catch is CancellationError {
                self.isSending = false
            } catch {
                guard !Task.isCancelled else { return }
                self.isSending = false
                self.statusMessage = error.localizedDescription
                self.notifyPresentationChange()
            }
        }
    }

    private func startRecording() {
        guard credentials.openAIAPIKey() != nil else {
            statusMessage = CompactOverlayChatStrings.missingOpenAIAPIKey
            notifyPresentationChange()
            return
        }

        transcriptionTask?.cancel()
        sendTask?.cancel()
        isSending = false
        isStartingRecording = true

        Task { [weak self] in
            guard let self else { return }
            defer { self.isStartingRecording = false }
            let granted = await self.recorder.requestPermission()
            guard granted else {
                self.statusMessage = MicrophoneRecordingError.permissionDenied.localizedDescription
                self.notifyPresentationChange()
                return
            }

            do {
                try self.recorder.startRecording()
                self.voicePhase = .recording
                self.statusMessage = nil
                self.startRecordingTimeout()
                self.notifyPresentationChange()
            } catch {
                self.voicePhase = .idle
                self.statusMessage = error.localizedDescription
                self.notifyPresentationChange()
            }
        }
    }

    private func stopRecordingAndTranscribe() {
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil

        let audioData: Data
        do {
            audioData = try recorder.stopRecording()
        } catch {
            voicePhase = .idle
            statusMessage = error.localizedDescription
            notifyPresentationChange()
            return
        }

        guard let apiKey = credentials.openAIAPIKey() else {
            voicePhase = .idle
            statusMessage = CompactOverlayChatStrings.missingOpenAIAPIKey
            notifyPresentationChange()
            return
        }

        voicePhase = .transcribing
        statusMessage = nil
        notifyPresentationChange()

        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await self.transcribeUseCase.perform(apiKey: apiKey, audioData: audioData)
                guard !Task.isCancelled else { return }
                self.draftText = text
                self.voicePhase = .draft
                self.statusMessage = nil
                self.notifyPresentationChange()
            } catch is CancellationError {
                self.voicePhase = .idle
            } catch {
                guard !Task.isCancelled else { return }
                self.voicePhase = .idle
                self.statusMessage = error.localizedDescription
                self.notifyPresentationChange()
            }
        }
    }

    private func startRecordingTimeout() {
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.maximumRecordingDuration))
            guard !Task.isCancelled else { return }
            self?.stopRecordingAndTranscribe()
        }
    }

    private func cancelInFlightWork() {
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        sendTask?.cancel()
        sendTask = nil
        isStartingRecording = false
    }

    private func notifyPresentationChange() {
        onPresentationChange?()
    }
}

enum CompactOverlayChatStrings {
    static let askByVoice = "Спросить голосом"
    static let stopRecording = "Остановить запись"
    static let send = "Отправить"
    static let recording = "Идёт запись. Нажмите ещё раз, чтобы остановить."
    static let transcribing = "Распознаю речь…"
    static let sending = "Отвечаю…"
    static let chatTitle = "Чат"
    static let closeChat = "Закрыть чат"
    static let draftPlaceholder = "Распознанный вопрос"
    static let missingOpenAIAPIKey = "Для распознавания голоса нужен токен OpenAI."
    static let missingTextAPIKey = "Нет токена для выбранного текстового провайдера."
    static let missingTextModel = "Не выбрана текстовая модель."
    static let missingTranslationContext = "Нет перевода для контекста чата."
}
