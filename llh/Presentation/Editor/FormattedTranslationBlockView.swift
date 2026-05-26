//
//  FormattedTranslationBlockView.swift
//  llh
//

import SwiftUI

struct FormattedTranslationBlockView: View {
    let formatted: StructuredFormattedText
    let learningLanguage: LearningLanguage

    var body: some View {
        VStack(spacing: 10) {
            if formatted.showsSourceCaptionAbovePrimary(learningLanguage: learningLanguage) {
                Text(formatted.cleanedText)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }

            Text(formatted.primaryDisplayLine(learningLanguage: learningLanguage))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            Text(formatted.russianTranslation)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background.secondary)
        )
    }
}
