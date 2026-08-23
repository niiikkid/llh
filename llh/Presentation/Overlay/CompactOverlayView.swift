//
//  CompactOverlayView.swift
//  llh
//

import SwiftUI

enum CompactOverlayContent: Equatable {
    case loading(String)
    case translation(formattedText: StructuredFormattedText, wordsPhase: CompactOverlayWordsPhase?)
    case message(title: String, subtitle: String?)

    var contentKind: CompactOverlayContentKind {
        switch self {
        case .loading: .loading
        case .translation: .translation
        case .message: .message
        }
    }
}

enum CompactOverlayContentKind {
    case loading
    case translation
    case message
}

enum CompactOverlayLayout {
    static let translationCardWidth: CGFloat = 360
    static let chatCardWidth: CGFloat = 280
    static let cardSpacing: CGFloat = 10
    static let maxWidthWithoutChat: CGFloat = 460
    static let maxWidthWithChat: CGFloat = translationCardWidth + cardSpacing + chatCardWidth + 16
}

struct CompactOverlayView: View {
    let content: CompactOverlayContent
    let chatViewModel: CompactOverlayChatViewModel?
    let onClose: () -> Void

    var contentKind: CompactOverlayContentKind {
        content.contentKind
    }

    var body: some View {
        HStack(alignment: .top, spacing: CompactOverlayLayout.cardSpacing) {
            translationCard

            if let chatViewModel, chatViewModel.isChatPanelVisible {
                CompactOverlayChatPanelView(viewModel: chatViewModel)
            }
        }
    }

    private var translationCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                switch content {
                case .loading(let text):
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                case .translation(let formattedText, let wordsPhase):
                    CompactOverlayTranslationSectionView(
                        formattedText: formattedText,
                        wordsPhase: wordsPhase,
                        chatViewModel: chatViewModel
                    )

                case .message(let title, let subtitle):
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(subtitle)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                    .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(10)
            .help("Закрыть (Escape)")
        }
        .frame(width: CompactOverlayLayout.translationCardWidth)
        .background(compactOverlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }
}

private struct CompactOverlayTranslationSectionView: View {
    let formattedText: StructuredFormattedText
    let wordsPhase: CompactOverlayWordsPhase?
    let chatViewModel: CompactOverlayChatViewModel?

    var body: some View {
        let primaryText = formattedText.overlayPrimaryText
        let secondaryText = formattedText.russianTranslation

        VStack(spacing: 10) {
            if !primaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(primaryText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }

            HStack(alignment: .top, spacing: 8) {
                Text(secondaryText)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                if let chatViewModel {
                    CompactOverlayVoiceButton(viewModel: chatViewModel)
                }
            }

            if let chatViewModel {
                CompactOverlayVoiceStatusView(viewModel: chatViewModel)
                if !chatViewModel.isChatPanelVisible {
                    CompactOverlayDraftComposerView(viewModel: chatViewModel)
                }
            }

            if let wordsPhase {
                CompactOverlayWordsSectionView(phase: wordsPhase)
            }
        }
    }
}

private struct CompactOverlayVoiceButton: View {
    @ObservedObject var viewModel: CompactOverlayChatViewModel

    var body: some View {
        Button(action: viewModel.handleMicTapped) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(viewModel.isRecording ? Color.red : Color.accentColor)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isTranscribing)
        .help(viewModel.isRecording ? CompactOverlayChatStrings.stopRecording : CompactOverlayChatStrings.askByVoice)
    }

    private var symbolName: String {
        if viewModel.isRecording {
            return "stop.circle.fill"
        }
        if viewModel.isTranscribing {
            return "waveform"
        }
        return "mic.circle.fill"
    }
}

private struct CompactOverlayVoiceStatusView: View {
    @ObservedObject var viewModel: CompactOverlayChatViewModel

    var body: some View {
        if viewModel.isRecording {
            Text(CompactOverlayChatStrings.recording)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        } else if viewModel.isTranscribing {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(CompactOverlayChatStrings.transcribing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let statusMessage = viewModel.statusMessage, !viewModel.isChatPanelVisible {
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
        }
    }
}

private struct CompactOverlayDraftComposerView: View {
    @ObservedObject var viewModel: CompactOverlayChatViewModel

    var body: some View {
        if viewModel.voicePhase == .draft || viewModel.hasDraft {
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    CompactOverlayChatStrings.draftPlaceholder,
                    text: $viewModel.draftText,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(2...5)

                Button(CompactOverlayChatStrings.send, action: viewModel.sendDraft)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!viewModel.canSend)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CompactOverlayChatPanelView: View {
    @ObservedObject var viewModel: CompactOverlayChatViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(CompactOverlayChatStrings.chatTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 22)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            CompactOverlayChatBubbleView(message: message)
                        }
                        if viewModel.isSending {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(CompactOverlayChatStrings.sending)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)

                CompactOverlayDraftComposerView(viewModel: viewModel)

                if let statusMessage = viewModel.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            Button(action: viewModel.closeChatPanel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(8)
            .help(CompactOverlayChatStrings.closeChat)
        }
        .frame(width: CompactOverlayLayout.chatCardWidth)
        .background(compactOverlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }
}

private struct CompactOverlayChatBubbleView: View {
    let message: TranslationChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 16)
            }

            Text(message.text)
                .font(.system(size: 12))
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(message.role == .user ? Color.accentColor.opacity(0.92) : Color.white.opacity(0.12))
                )

            if message.role == .assistant {
                Spacer(minLength: 16)
            }
        }
    }
}

private struct CompactOverlayWordsSectionView: View {
    let phase: CompactOverlayWordsPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 2)

            switch phase {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Перевожу слова…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            case .ready(let payload):
                Text("Перевод слов")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(payload.entries.enumerated()), id: \.offset) { _, entry in
                            CompactOverlayWordEntryRowView(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 180)

            case .failed:
                Text("Не удалось перевести слова.")
                    .font(.caption)
                    .foregroundStyle(.orange)

            case .unavailable:
                Text("Перевод слов недоступен для этой сессии.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompactOverlayWordEntryRowView: View {
    let entry: WordStudyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.termPinyin)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                if !entry.russianPronunciationGuide.isEmpty {
                    Text("(\(entry.russianPronunciationGuide))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text("—")
                    .foregroundStyle(.secondary)
                Text(entry.termTranslation)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private var compactOverlayBackground: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(.ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.24))
        )
}
