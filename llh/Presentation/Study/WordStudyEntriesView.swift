//
//  WordStudyEntriesView.swift
//  llh
//

import SwiftUI

struct WordStudyEntriesView: View {
    let payload: WordStudyPayload?

    var body: some View {
        if let payload, !payload.entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(payload.entries.enumerated()), id: \.offset) { _, entry in
                    WordStudyEntryRowView(entry: entry)
                }
            }
        } else {
            ContentUnavailableView(
                "Слова не найдены",
                systemImage: "list.bullet.rectangle",
                description: Text("Для этой записи AI не выделил слов для изучения.")
            )
        }
    }
}

private struct WordStudyEntryRowView: View {
    let entry: WordStudyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.termPinyin)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                if !entry.russianPronunciationGuide.isEmpty {
                    Text("(\(entry.russianPronunciationGuide))")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundStyle(.secondary)
                }
                Text("-")
                    .font(.system(size: 17, weight: .regular, design: .default))
                Text(entry.termTranslation)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)

            if !entry.characterBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Разбор")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(entry.characterBreakdown.enumerated()), id: \.offset) { _, part in
                        HStack(alignment: .top, spacing: 8) {
                            Text(part.pinyinText)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .frame(width: 120, alignment: .leading)
                                .textSelection(.enabled)
                            Text(part.russianTranslation)
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
