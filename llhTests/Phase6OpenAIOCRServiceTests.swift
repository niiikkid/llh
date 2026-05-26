//
//  Phase6OpenAIOCRServiceTests.swift
//  llhTests
//

import CoreGraphics
import Foundation
import Testing
@testable import llh

struct Phase6OpenAIOCRServiceTests {
    @Test
    func recognizeTextInImage_postsVisionChatCompletionAndReturnsNormalizedText() async throws {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAIOCRService(httpClient: client)
        let responseJSON = """
        {"choices":[{"message":{"content":"  line one\\nline two  "}}]}
        """

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString.hasSuffix("/v1/chat/completions") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(responseJSON.utf8))
        }

        let text = try await service.recognizeTextInImage(
            apiKey: "sk-test",
            modelID: "gpt-4o",
            image: makeTestCGImage()
        )

        #expect(text == "line one\nline two")
    }

    @Test
    func recognizeTextInImage_emptyModelIDThrowsInvalidResponse() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAIOCRService(httpClient: client)

        await #expect(throws: OpenAIServiceError.invalidResponse) {
            _ = try await service.recognizeTextInImage(
                apiKey: "sk-test",
                modelID: "   ",
                image: makeTestCGImage()
            )
        }
    }

    @Test
    func recognizeTextInImage_emptyContentThrowsEmptyRecognizedText() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAIOCRService(httpClient: client)
        let responseJSON = """
        {"choices":[{"message":{"content":"   "}}]}
        """

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 200)
            return (response, Data(responseJSON.utf8))
        }

        await #expect(throws: OpenAIServiceError.emptyRecognizedText) {
            _ = try await service.recognizeTextInImage(
                apiKey: "sk-test",
                modelID: "gpt-4o",
                image: makeTestCGImage()
            )
        }
    }

    @Test
    func recognizeTextInImage_mapsUnauthorizedThroughHTTPClient() async {
        let client = OpenAIHTTPClientTestSupport.makeClient()
        let service = OpenAIOCRService(httpClient: client)

        OpenAIHTTPClientURLProtocolStub.requestHandler = { request in
            let response = OpenAIHTTPClientTestSupport.httpResponse(for: request, statusCode: 401)
            return (response, Data())
        }

        await #expect(throws: OpenAIServiceError.unauthorized) {
            _ = try await service.recognizeTextInImage(
                apiKey: "sk-test",
                modelID: "gpt-4o",
                image: makeTestCGImage()
            )
        }
    }
}

private func makeTestCGImage() -> CGImage {
    let width = 8
    let height = 8
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}
