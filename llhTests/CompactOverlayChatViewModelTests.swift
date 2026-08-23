//
//  CompactOverlayChatViewModelTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

@MainActor
private final class FakeMicrophoneRecorder: MicrophoneRecording {
    var permissionGranted = true
    var audioData = Data("voice".utf8)
    var startError: Error?
    var stopError: Error?
    private(set) var didStart = false
    private(set) var didCancel = false

    func requestPermission() async -> Bool {
        permissionGranted
    }

    func startRecording() throws {
        if let startError {
            throw startError
        }
        didStart = true
    }

    func stopRecording() throws -> Data {
        if let stopError {
            throw stopError
        }
        return audioData
    }

    func cancelRecording() {
        didCancel = true
    }
}

private final class FakeSpeechTranscriptionServing: SpeechTranscriptionServing {
    var text = "Что значит это слово?"

    func transcribeSpeech(
        apiKey: String,
        modelID: String,
        audioData: Data,
        filename: String,
        mimeType: String
    ) async throws -> String {
        text
    }
}

private final class FakeTranslationChatServing: TranslationChatServing {
    var reply = "Это приветствие."
    private(set) var lastProvider: AIProvider?

    func completeTranslationChat(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        context: TranslationChatContext,
        messages: [TranslationChatMessage]
    ) async throws -> String {
        lastProvider = provider
        return reply
    }
}

@MainActor
struct CompactOverlayChatViewModelTests {
    @Test
    func recordThenSend_opensChatPanelWithDeepSeekReply() async throws {
        let recorder = FakeMicrophoneRecorder()
        let chatService = FakeTranslationChatServing()
        let viewModel = makeViewModel(
            recorder: recorder,
            chatService: chatService,
            provider: .deepSeek
        )
        viewModel.updateContext(
            TranslationChatContext(
                formattedText: StructuredFormattedText(
                    cleanedText: "你好",
                    pinyinText: "nǐ hǎo",
                    russianTranslation: "привет"
                )
            )
        )

        viewModel.handleMicTapped()
        try await waitUntil { recorder.didStart }
        #expect(viewModel.isRecording)

        viewModel.handleMicTapped()
        try await waitUntil { viewModel.voicePhase == .draft }
        #expect(viewModel.draftText == "Что значит это слово?")
        #expect(viewModel.isSidePanelVisible)

        viewModel.sendDraft()
        try await waitUntil { viewModel.messages.contains(where: { $0.role == .assistant }) }

        #expect(viewModel.isChatPanelVisible)
        #expect(viewModel.messages.map(\.text) == ["Что значит это слово?", "Это приветствие."])
        #expect(chatService.lastProvider == .deepSeek)
    }

    @Test
    func missingOpenAIKey_doesNotStartRecording() {
        let recorder = FakeMicrophoneRecorder()
        let viewModel = makeViewModel(recorder: recorder, openAIAPIKey: nil)

        viewModel.handleMicTapped()

        #expect(recorder.didStart == false)
        #expect(viewModel.statusMessage == CompactOverlayChatStrings.missingOpenAIAPIKey)
    }

    @Test
    func closeChatPanel_keepsHistory() async throws {
        let viewModel = makeViewModel()
        viewModel.updateContext(
            TranslationChatContext(
                formattedText: StructuredFormattedText(
                    cleanedText: "hi",
                    pinyinText: "",
                    russianTranslation: "привет"
                )
            )
        )
        viewModel.handleMicTapped()
        try await waitUntil { viewModel.isRecording }
        viewModel.handleMicTapped()
        try await waitUntil { viewModel.hasDraft }
        viewModel.sendDraft()
        try await waitUntil { viewModel.isChatPanelVisible }

        viewModel.closeChatPanel()

        #expect(viewModel.isChatPanelVisible == false)
        #expect(viewModel.messages.isEmpty == false)
    }

    private func makeViewModel(
        recorder: FakeMicrophoneRecorder = FakeMicrophoneRecorder(),
        chatService: FakeTranslationChatServing = FakeTranslationChatServing(),
        provider: AIProvider = .openAI,
        openAIAPIKey: String? = "sk-openai"
    ) -> CompactOverlayChatViewModel {
        CompactOverlayChatViewModel(
            recorder: recorder,
            transcribeUseCase: TranscribeSpeechUseCase(service: FakeSpeechTranscriptionServing()),
            chatUseCase: AskTranslationChatUseCase(service: chatService),
            credentials: CompactOverlayChatCredentials(
                openAIAPIKey: { openAIAPIKey },
                textProvider: { provider },
                textAPIKey: { "sk-text" },
                textModelID: { provider == .deepSeek ? "deepseek-chat" : "gpt-4o" }
            )
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Timed out waiting for overlay chat condition")
    }
}
