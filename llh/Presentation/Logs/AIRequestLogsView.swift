//
//  AIRequestLogsView.swift
//  llh
//

import AppKit
import SwiftUI

struct AIRequestLogsView: View {
    @ObservedObject var store: InMemoryAITextRequestLogStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Text("Только текстовые запросы к ИИ: что ушло, что пришло и какая модель. Токены и картинки OCR сюда не пишутся. Логи только в памяти, до закрытия приложения.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.entries) { entry in
                            AIRequestLogEntryCard(entry: entry)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 520)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Логи запросов к ИИ")
                .font(.title3.weight(.semibold))
            Spacer()
            Button("Очистить") {
                store.clear()
            }
            .disabled(store.entries.isEmpty)
            Button("Закрыть") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Запросов пока нет")
                .font(.headline)
            Text("После перевода, разбора слов или чата здесь появятся полные тексты запросов и ответов.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AIRequestLogEntryCard: View {
    let entry: AITextRequestLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.operation.title)
                    .font(.headline)
                Spacer()
                Button("Копировать") {
                    copyToPasteboard(entry.plainTextReport)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                statusBadge
                Text(entry.createdAt.formatted(date: .abbreviated, time: .standard))
                Text("·")
                Text(entry.provider.title)
                Text("·")
                Text(entry.modelID)
                    .textSelection(.enabled)
                Text("·")
                Text(AITextRequestLogEntry.formattedDuration(entry.duration))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(Array(entry.messages.enumerated()), id: \.offset) { _, message in
                logBlock(title: message.displayRole, text: message.content)
            }

            if let errorDescription = entry.errorDescription {
                logBlock(title: "Ошибка", text: errorDescription)
            } else {
                logBlock(title: "Ответ", text: entry.responseText ?? "")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary.opacity(0.45))
        )
    }

    private var statusBadge: some View {
        Text(entry.didSucceed ? "успех" : "ошибка")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(entry.didSucceed ? Color.green.opacity(0.18) : Color.orange.opacity(0.22))
            )
            .foregroundStyle(entry.didSucceed ? Color.green : Color.orange)
    }

    private func logBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text.isEmpty ? "—" : text)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.background)
        )
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
