//
//  AITextRequestLogStoreTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct AITextRequestLogStoreTests {
    @Test
    @MainActor
    func record_keepsNewestFirstAndCaps() {
        let store = InMemoryAITextRequestLogStore(maximumEntryCount: 2)

        store.record(makeEntry(modelID: "first"))
        store.record(makeEntry(modelID: "second"))
        store.record(makeEntry(modelID: "third"))

        #expect(store.entries.map(\.modelID) == ["third", "second"])
    }

    @Test
    @MainActor
    func clear_removesAllEntries() {
        let store = InMemoryAITextRequestLogStore()
        store.record(makeEntry(modelID: "gpt-4o"))

        store.clear()

        #expect(store.entries.isEmpty)
    }

    @Test
    @MainActor
    func asLogger_recordsOnTheStore() async {
        let store = InMemoryAITextRequestLogStore()

        store.asLogger.record(makeEntry(modelID: "hopped"))
        await waitUntil { !store.entries.isEmpty }

        #expect(store.entries.map(\.modelID) == ["hopped"])
    }

    @Test
    func plainTextReport_includesModelRequestAndResponse() {
        let entry = makeEntry(
            modelID: "deepseek-chat",
            messages: [
                AITextRequestLogMessage(role: "system", content: "Переведи текст"),
                AITextRequestLogMessage(role: "user", content: "你好")
            ],
            responseText: "привет"
        )

        #expect(entry.plainTextReport.contains("DeepSeek"))
        #expect(entry.plainTextReport.contains("deepseek-chat"))
        #expect(entry.plainTextReport.contains("Переведи текст"))
        #expect(entry.plainTextReport.contains("你好"))
        #expect(entry.plainTextReport.contains("привет"))
        #expect(entry.plainTextReport.contains("Форматирование и перевод"))
    }
}

struct OpenAIChatCompletionClientLoggingTests {
    @Test
    func completeText_recordsModelMessagesAndResponseWithoutAPIKey() async throws {
        let logger = RecordingAITextRequestLogger()
        let client = OpenAIChatCompletionClient(
            httpClient: OpenAIHTTPClientTestSupport.makeClient(),
            provider: .openAI,
            requestLogger: logger
        )
        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            let body = #"{"choices":[{"message":{"content":"привет"}}]}"#
            return (response, Data(body.utf8))
        }

        let content = try await client.completeText(
            apiKey: "sk-secret-token",
            modelID: "gpt-4o",
            temperature: 0,
            systemPrompt: "Системный промпт",
            userPrompt: "Пользовательский текст",
            operation: .formatRecognizedText
        )

        #expect(content == "привет")
        #expect(logger.entries.count == 1)
        let entry = try #require(logger.entries.first)
        #expect(entry.modelID == "gpt-4o")
        #expect(entry.provider == .openAI)
        #expect(entry.operation == .formatRecognizedText)
        #expect(entry.messages.map(\.content) == ["Системный промпт", "Пользовательский текст"])
        #expect(entry.responseText == "привет")
        #expect(entry.errorDescription == nil)
        #expect(entry.plainTextReport.contains("sk-secret-token") == false)
    }

    @Test
    func completeConversation_recordsErrorAndStillKeepsRequestText() async {
        let logger = RecordingAITextRequestLogger()
        let client = OpenAIChatCompletionClient(
            httpClient: OpenAIHTTPClientTestSupport.makeClient(),
            provider: .deepSeek,
            requestLogger: logger
        )
        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 401)
            return (response, Data())
        }

        await #expect(throws: OpenAIServiceError.unauthorized) {
            _ = try await client.completeConversation(
                apiKey: "sk-secret-token",
                modelID: "deepseek-chat",
                temperature: 0.3,
                messages: [
                    ChatCompletionTurn(role: "user", content: "что значит 你好")
                ],
                operation: .translationChat
            )
        }

        #expect(logger.entries.count == 1)
        let entry = logger.entries[0]
        #expect(entry.modelID == "deepseek-chat")
        #expect(entry.provider == .deepSeek)
        #expect(entry.operation == .translationChat)
        #expect(entry.messages.map(\.content) == ["что значит 你好"])
        #expect(entry.responseText == nil)
        #expect(entry.errorDescription == OpenAIServiceError.unauthorized.errorDescription)
        #expect(entry.plainTextReport.contains("sk-secret-token") == false)
    }
}

private final class RecordingAITextRequestLogger: AITextRequestLogging, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [AITextRequestLogEntry] = []

    func record(_ entry: AITextRequestLogEntry) {
        lock.lock()
        stored.append(entry)
        lock.unlock()
    }

    var entries: [AITextRequestLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

private func waitUntil(
    timeout: Duration = .seconds(1),
    _ predicate: @MainActor () -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if predicate() {
            return
        }
        await Task.yield()
    }
}

private func makeEntry(
    modelID: String,
    messages: [AITextRequestLogMessage] = [
        AITextRequestLogMessage(role: "user", content: "hello")
    ],
    responseText: String? = "ok"
) -> AITextRequestLogEntry {
    AITextRequestLogEntry(
        operation: .formatRecognizedText,
        provider: .deepSeek,
        modelID: modelID,
        messages: messages,
        responseText: responseText,
        errorDescription: nil,
        duration: 0.12
    )
}
