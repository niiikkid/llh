//
//  SessionLanguageBadge.swift
//  llh
//

import SwiftUI

struct SessionLanguageBadge: View {
    let language: LearningLanguage

    private let iconFont: Font = .title2

    var body: some View {
        HStack(spacing: 8) {
            languageIcon
            Text(language.title)
                .font(.caption)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Язык сессии: \(language.title)")
    }

    @ViewBuilder
    private var languageIcon: some View {
        if language == .auto {
            Image(systemName: "globe")
                .font(iconFont)
                .foregroundStyle(.secondary)
        } else if let flagEmoji = language.flagEmoji {
            Text(flagEmoji)
                .font(iconFont)
                .foregroundStyle(.secondary)
        }
    }
}
