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
                ForEach(Array(payload.structures.filter(\.hasVisibleContent).enumerated()), id: \.offset) { _, structure in
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
        GrammarStructureLinesView(structure: structure, fontSizePoints: 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.background)
            )
    }
}
