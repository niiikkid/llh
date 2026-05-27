//
//  GrammarExplanationView.swift
//  llh
//

import SwiftUI

struct GrammarExplanationView: View {
    let payload: GrammarExplanationPayload?

    var body: some View {
        if let payload, payload.hasContent {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(payload.structures.enumerated()), id: \.offset) { _, structure in
                    GrammarStructureCardView(structure: structure)
                }
            }
        } else {
            ContentUnavailableView(
                "Грамматика не найдена",
                systemImage: "text.book.closed",
                description: Text("Для этой записи AI не выделил грамматических конструкций.")
            )
        }
    }
}

private struct GrammarStructureCardView: View {
    let structure: GrammarStructure

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !structure.title.isEmpty {
                Text(structure.title)
                    .font(.headline)
            }

            if !structure.explanation.isEmpty {
                Text(structure.explanation)
                    .font(.body)
                    .textSelection(.enabled)
            }

            if !structure.usageNotes.isEmpty {
                Text(structure.usageNotes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !structure.examples.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Примеры")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(structure.examples.enumerated()), id: \.offset) { _, example in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(example.pinyinText)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .textSelection(.enabled)
                            Text("—")
                                .foregroundStyle(.secondary)
                            Text(example.russianTranslation)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background)
        )
    }
}
