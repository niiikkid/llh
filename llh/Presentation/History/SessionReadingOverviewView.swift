//
//  SessionReadingOverviewView.swift
//  llh
//

import SwiftUI

struct SessionReadingOverviewView: View {
    @ObservedObject var history: HistoryViewModel
    @State private var fontSizePoints: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    history.copySessionReadingOverviewToPasteboard()
                } label: {
                    Label("Копировать весь текст", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Скопировать все фрагменты сессии в буфер обмена.")

                Spacer(minLength: 0)
                Button {
                    fontSizePoints = max(12, fontSizePoints - 1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(fontSizePoints <= 12)
                .help("Уменьшить размер текста")

                Button {
                    fontSizePoints = min(24, fontSizePoints + 1)
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(fontSizePoints >= 24)
                .help("Увеличить размер текста")
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(history.sessionReadingSequence.enumerated()), id: \.element.id) { index, item in
                        SessionReadingItemView(item: item, fontSizePoints: fontSizePoints)

                        if index < history.sessionReadingSequence.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SessionReadingItemView: View {
    let item: SessionReadingSequenceItem
    let fontSizePoints: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.sourceLine.isEmpty {
                Text(item.displaySourceLine)
                    .font(.system(size: fontSizePoints))
                    .foregroundStyle(.tertiary)
            } else {
                Text(item.sourceLine)
                    .font(.system(size: fontSizePoints, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            if item.translationLine.isEmpty {
                Text(item.displayTranslationLine)
                    .font(.system(size: max(11, fontSizePoints - 2)))
                    .foregroundStyle(.tertiary)
            } else {
                Text(item.translationLine)
                    .font(.system(size: max(11, fontSizePoints - 2)))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
