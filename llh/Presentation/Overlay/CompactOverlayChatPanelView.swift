//
//  CompactOverlayChatPanelView.swift
//  llh
//

import SwiftUI

struct CompactOverlayChatWindowRoot: View {
    var viewModel: CompactOverlayChatViewModel?

    var body: some View {
        if let viewModel {
            CompactOverlayChatHost(viewModel: viewModel)
        }
    }
}

struct CompactOverlayChatHost: View {
    @ObservedObject var viewModel: CompactOverlayChatViewModel

    var body: some View {
        CompactOverlayChatPanelView(viewModel: viewModel)
    }
}

struct CompactOverlayChatPanelView: View {
    @ObservedObject var viewModel: CompactOverlayChatViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(panelTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 22)

                if viewModel.isTranscribing && viewModel.messages.isEmpty && !viewModel.hasDraft {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(CompactOverlayChatStrings.transcribing)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !viewModel.messages.isEmpty || viewModel.isSending {
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
                }

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
        .background(CompactOverlayCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }

    private var panelTitle: String {
        viewModel.messages.isEmpty ? CompactOverlayChatStrings.recognizedTitle : CompactOverlayChatStrings.chatTitle
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
                .lineLimit(2...6)

                HStack {
                    Spacer()
                    Button(CompactOverlayChatStrings.send, action: viewModel.sendDraft)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!viewModel.canSend)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
