//
//  GrammarStructureLinesView.swift
//  llh
//

import SwiftUI

/// Shared grammar structure body for study panel and session reading overview.
struct GrammarStructureLinesView: View {
    let structure: GrammarStructure
    let fontSizePoints: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !structure.title.isEmpty {
                Text(structure.title)
                    .font(.system(size: fontSizePoints + 1, weight: .semibold))
            }
            if !structure.explanation.isEmpty {
                Text(structure.explanation)
                    .font(.system(size: fontSizePoints))
                    .textSelection(.enabled)
            }
            if !structure.usageNotes.isEmpty {
                Text(structure.usageNotes)
                    .font(.system(size: fontSizePoints))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !structure.examples.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Примеры")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(structure.examples.enumerated()), id: \.offset) { _, example in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(example.pinyinText)
                                .font(.system(size: fontSizePoints, weight: .medium, design: .rounded))
                                .textSelection(.enabled)
                            Text("—")
                                .foregroundStyle(.secondary)
                            Text(example.russianTranslation)
                                .font(.system(size: fontSizePoints))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}
