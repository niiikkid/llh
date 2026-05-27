//
//  SessionLanguageBadge.swift
//  llh
//

import SwiftUI

struct SessionLanguageBadge: View {
    let language: LearningLanguage

    var body: some View {
        HStack(spacing: 6) {
            if language == .auto {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let flagEmoji = language.flagEmoji {
                Text(flagEmoji)
                    .font(.caption)
            }
            Text(language.title)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(.background.secondary)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Язык сессии: \(language.title)")
    }
}
