//
//  Phase6OpenAITranscriptionServiceTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

struct Phase6OpenAITranscriptionServiceTests {
    @Test
    func transcribeSpeech_postsMultipartToOpenAITranscriptions() async throws {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAITranscriptionService(httpClient: client)
        let audio = Data("fake-audio".utf8)

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
            #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
            let body = OpenAIHTTPClientTestSupport.bodyData(from: request) ?? Data()
            let bodyText = String(decoding: body, as: UTF8.self)
            #expect(bodyText.contains("gpt-transcribe"))
            #expect(bodyText.contains("speech.m4a"))
            #expect(bodyText.contains("fake-audio"))
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(#"{"text":"распознанный вопрос"}"#.utf8))
        }

        let text = try await service.transcribeSpeech(
            apiKey: "sk-test",
            modelID: SpeechTranscriptionModel.currentOpenAIModelID,
            audioData: audio,
            filename: "speech.m4a",
            mimeType: "audio/mp4"
        )

        #expect(text == "распознанный вопрос")
    }

    @Test
    func transcribeSpeech_emptyTextThrows() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAITranscriptionService(httpClient: client)

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(#"{"text":"  "}"#.utf8))
        }

        await #expect(throws: OpenAIServiceError.emptyTranscription) {
            _ = try await service.transcribeSpeech(
                apiKey: "sk-test",
                modelID: "gpt-transcribe",
                audioData: Data("abc".utf8),
                filename: "speech.m4a",
                mimeType: "audio/mp4"
            )
        }
    }
}
