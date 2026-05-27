//
//  TranslationResultPresentationResolverTests.swift
//  llhTests
//

import Testing
@testable import llh

struct TranslationResultPresentationResolverTests {
    private let sampleFormatted = StructuredFormattedText(
        cleanedText: "你好",
        pinyinText: "nǐ hǎo",
        russianTranslation: "привет"
    )

    @Test
    func resolve_returnsLoadingWhenProcessingFlagSet() {
        let result = TranslationResultPresentationResolver.resolve(
            formattingStatus: .notRequested,
            isFormattingRecognizedText: true,
            formattedText: nil
        )

        #expect(result == .loading)
    }

    @Test
    func resolve_returnsLoadingWhenStatusIsProcessing() {
        let result = TranslationResultPresentationResolver.resolve(
            formattingStatus: .processing,
            isFormattingRecognizedText: false,
            formattedText: nil
        )

        #expect(result == .loading)
    }

    @Test
    func resolve_returnsFormattedWhenSucceededWithContent() {
        let result = TranslationResultPresentationResolver.resolve(
            formattingStatus: .succeeded,
            isFormattingRecognizedText: false,
            formattedText: sampleFormatted
        )

        #expect(result == .formatted)
    }

    @Test
    func resolve_returnsFailedWhenStatusFailed() {
        let result = TranslationResultPresentationResolver.resolve(
            formattingStatus: .failed,
            isFormattingRecognizedText: false,
            formattedText: nil
        )

        #expect(result == .failed)
    }

    @Test
    func resolve_returnsRawOnlyWhenNotRequested() {
        let result = TranslationResultPresentationResolver.resolve(
            formattingStatus: .notRequested,
            isFormattingRecognizedText: false,
            formattedText: nil
        )

        #expect(result == .rawOnly)
    }

    @Test
    func resolve_prefersLoadingOverSucceededContent() {
        let result = TranslationResultPresentationResolver.resolve(
            formattingStatus: .succeeded,
            isFormattingRecognizedText: true,
            formattedText: sampleFormatted
        )

        #expect(result == .loading)
    }
}
