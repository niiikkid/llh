//
//  OCRService.swift
//  llh
//

import CoreGraphics
import Foundation
import Vision

struct OCRService {
    func recognizeText(in image: CGImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ru-RU"]
            request.automaticallyDetectsLanguage = true
            request.minimumTextHeight = 0.015

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            return TextFormatter.normalizeRecognizedLines(lines)
        }.value
    }
}
