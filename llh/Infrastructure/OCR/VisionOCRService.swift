//
//  VisionOCRService.swift
//  llh
//

import CoreGraphics
import Foundation
import Vision

/// Local OCR via Apple Vision (`VNRecognizeTextRequest`).
struct VisionOCRService: Sendable {
    nonisolated func recognizeText(in image: CGImage) async throws -> OCRResult {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ru-RU"]
            request.automaticallyDetectsLanguage = true
            request.minimumTextHeight = 0.015

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            try Task.checkCancellation()

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            let text = TextFormatter.normalizeRecognizedLines(lines)
            return OCRResult(text: text, lines: lines)
        }.value
    }
}
