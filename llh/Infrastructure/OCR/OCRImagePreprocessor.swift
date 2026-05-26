//
//  OCRImagePreprocessor.swift
//  llh
//

import CoreGraphics
import Foundation
import ImageIO

/// JPEG encoding for AI OCR requests. Runs off the main actor.
enum OCRImagePreprocessor: Sendable {
    nonisolated static func jpegData(
        from image: CGImage,
        compressionQuality: CGFloat = 0.9
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard let data = jpegDataSync(from: image, compressionQuality: compressionQuality),
                  !data.isEmpty else {
                throw OpenAIServiceError.invalidImageData
            }
            return data
        }.value
    }

    private nonisolated static func jpegDataSync(
        from image: CGImage,
        compressionQuality: CGFloat
    ) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            return nil
        }
        let options: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }
}
