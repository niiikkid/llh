//
//  TranslationResultPresentation.swift
//  llh
//

import Foundation

enum TranslationResultPresentation: Equatable {
    case loading
    case formatted
    case failed
    case rawOnly
}

enum TranslationResultPresentationResolver {
    static func resolve(
        formattingStatus: FormattingStatus?,
        isFormattingRecognizedText: Bool,
        formattedText: StructuredFormattedText?
    ) -> TranslationResultPresentation {
        if isFormattingRecognizedText || formattingStatus == .processing {
            return .loading
        }

        if let formattedText,
           formattedText.hasContent,
           formattingStatus == .succeeded {
            return .formatted
        }

        if formattingStatus == .failed {
            return .failed
        }

        return .rawOnly
    }
}
