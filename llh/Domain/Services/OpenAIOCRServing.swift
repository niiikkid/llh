//
//  OpenAIOCRServing.swift
//  llh
//

import CoreGraphics
import Foundation

/// AI OCR via OpenAI vision (`POST /v1/chat/completions`). Separate from local `OCRServing`.
protocol OpenAIOCRServing: Sendable {
    func recognizeTextInImage(
        apiKey: String,
        modelID: String,
        image: CGImage
    ) async throws -> OCRResult
}
