//
//  RecognizeTextUseCase.swift
//  llh
//

import CoreGraphics
import Foundation

struct RecognizeTextConfiguration: Sendable {
    let ocrEngine: OCREngine
    let apiKey: String?
    let selectedModelID: String?
}

@MainActor
struct RecognizeTextUseCase {
    private let ocrService: OCRServing
    private let openAIService: OpenAIServing

    init(ocrService: OCRServing, openAIService: OpenAIServing) {
        self.ocrService = ocrService
        self.openAIService = openAIService
    }

    func execute(image: CGImage, configuration: RecognizeTextConfiguration) async throws -> String {
        switch configuration.ocrEngine {
        case .local:
            return try await ocrService.recognizeText(in: image)
        case .ai:
            guard let token = configuration.apiKey else {
                throw OpenAIServiceError.invalidTokenFormat
            }
            guard let modelID = configuration.selectedModelID else {
                throw OpenAIServiceError.invalidResponse
            }
            return try await openAIService.recognizeTextInImage(
                apiKey: token,
                modelID: modelID,
                image: image
            )
        }
    }
}
