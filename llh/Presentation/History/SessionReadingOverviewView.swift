//
//  SessionReadingOverviewView.swift
//  llh
//

import SwiftUI

struct SessionReadingOverviewView: View {
    @ObservedObject var history: HistoryViewModel
    @State private var fontSizePoints: CGFloat = 16
    @State private var expandedEntryIDs: Set<CapturedTextEntry.ID> = []

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
                        SessionReadingItemView(
                            item: item,
                            fontSizePoints: fontSizePoints,
                            isExpanded: expandedEntryIDs.contains(item.id),
                            onToggleDetails: { toggleDetails(for: item.id) }
                        )

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
        .onChange(of: history.showsSessionReadingOverview) { _, isShowing in
            if !isShowing {
                expandedEntryIDs = []
            }
        }
    }

    private func toggleDetails(for entryID: CapturedTextEntry.ID) {
        if expandedEntryIDs.contains(entryID) {
            expandedEntryIDs.remove(entryID)
        } else {
            expandedEntryIDs.insert(entryID)
        }
    }
}

private struct SessionReadingItemView: View {
    let item: SessionReadingSequenceItem
    let fontSizePoints: CGFloat
    let isExpanded: Bool
    let onToggleDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
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

                if item.hasExpandableDetails {
                    Button(action: onToggleDetails) {
                        Image(systemName: isExpanded ? "eye.fill" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help(isExpanded ? "Скрыть детали" : "Показать детали")
                }
            }

            if isExpanded, item.hasExpandableDetails {
                SessionReadingEntryDetailsView(item: item, fontSizePoints: fontSizePoints)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SessionReadingEntryDetailsView: View {
    let item: SessionReadingSequenceItem
    let fontSizePoints: CGFloat

    private var detailFontSize: CGFloat {
        max(11, fontSizePoints - 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let wordStudy = item.wordStudy {
                SessionReadingWordStudyDetailsView(
                    payload: wordStudy,
                    fontSizePoints: detailFontSize
                )
            }

            if let grammarStudy = item.grammarStudy {
                SessionReadingGrammarStudyDetailsView(
                    payload: grammarStudy,
                    fontSizePoints: detailFontSize
                )
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
    }
}

private struct SessionReadingWordStudyDetailsView: View {
    let payload: WordStudyPayload
    let fontSizePoints: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Перевод слов")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(payload.entries.enumerated()), id: \.offset) { _, entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(entry.termPinyin)
                            .font(.system(size: fontSizePoints + 1, weight: .semibold, design: .rounded))
                        if !entry.russianPronunciationGuide.isEmpty {
                            Text("(\(entry.russianPronunciationGuide))")
                                .font(.system(size: fontSizePoints))
                                .foregroundStyle(.secondary)
                        }
                        Text("—")
                            .foregroundStyle(.secondary)
                        Text(entry.termTranslation)
                            .font(.system(size: fontSizePoints))
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                    if !entry.characterBreakdown.isEmpty {
                        ForEach(Array(entry.characterBreakdown.enumerated()), id: \.offset) { _, part in
                            HStack(alignment: .top, spacing: 8) {
                                Text(part.pinyinText)
                                    .font(.system(size: fontSizePoints, weight: .medium, design: .rounded))
                                    .frame(minWidth: 72, alignment: .leading)
                                Text(part.russianTranslation)
                                    .font(.system(size: fontSizePoints))
                                    .foregroundStyle(.secondary)
                            }
                            .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}

private struct SessionReadingGrammarStudyDetailsView: View {
    let payload: GrammarExplanationPayload
    let fontSizePoints: CGFloat

    private var visibleStructures: [GrammarStructure] {
        payload.structures.filter(\.hasVisibleContent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Грамматика")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(visibleStructures.enumerated()), id: \.offset) { index, structure in
                GrammarStructureLinesView(structure: structure, fontSizePoints: fontSizePoints)
                if index < visibleStructures.count - 1 {
                    Divider()
                        .padding(.vertical, 2)
                }
            }
        }
    }
}
