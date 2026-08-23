//
//  OpenAITranscriptionService.swift
//  llh
//

import Foundation

/// File transcription via `POST /v1/audio/transcriptions`. Always OpenAI.
struct OpenAITranscriptionService: SpeechTranscriptionServing, Sendable {
    private let httpClient: OpenAIHTTPClient

    init(httpClient: OpenAIHTTPClient) {
        self.httpClient = httpClient
    }

    func transcribeSpeech(
        apiKey: String,
        modelID: String,
        audioData: Data,
        filename: String,
        mimeType: String
    ) async throws -> String {
        try Task.checkCancellation()

        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.invalidResponse
        }
        guard !audioData.isEmpty else {
            throw OpenAIServiceError.emptyTranscription
        }

        let data = try await httpClient.postMultipart(
            path: "/audio/transcriptions",
            apiKey: apiKey,
            fields: [
                MultipartFormField(name: "model", body: .text(modelID)),
                MultipartFormField(name: "response_format", body: .text("json")),
                MultipartFormField(
                    name: "file",
                    body: .file(data: audioData, filename: filename, mimeType: mimeType)
                )
            ]
        )
        try Task.checkCancellation()

        let decoded = try httpClient.decode(data, as: TranscriptionResponseDTO.self)
        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw OpenAIServiceError.emptyTranscription
        }
        return text
    }
}

private struct TranscriptionResponseDTO: Decodable {
    let text: String
}
