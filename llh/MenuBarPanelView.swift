//
//  MenuBarPanelView.swift
//  llh
//

import SwiftUI

struct MenuBarPanelView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LLH OCR")
                .font(.headline)

            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Button("Capture") {
                    viewModel.triggerCapture()
                }
                .disabled(viewModel.isProcessing)

                Button("Open Window") {
                    openWindow(id: "main-window")
                }
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
