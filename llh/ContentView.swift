//
//  ContentView.swift
//  llh
//
//  Created by itsme on 06.04.2026.
//

import SwiftUI
import KeyboardShortcuts

struct ContentView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var newProfileName = ""
    @State private var isCreateProfilePresented = false
    @State private var isDeleteProfileConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Screen OCR")
                .font(.title3.weight(.semibold))

            Text("Все данные обрабатываются локально на устройстве.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox("Shortcut") {
                HStack {
                    KeyboardShortcuts.Recorder("Capture area:", name: .captureArea)
                    Spacer()
                    Button("Capture now") {
                        viewModel.triggerCapture()
                    }
                    .disabled(viewModel.isProcessing)
                }
            }

            if viewModel.showPermissionHelp {
                GroupBox("Нужно разрешение Screen Recording") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Откройте System Settings -> Privacy & Security -> Screen Recording и включите доступ для приложения.")
                        HStack {
                            Button("Open System Settings") {
                                viewModel.openSystemSettings()
                            }
                            Button("Проверить снова") {
                                viewModel.refreshPermissionState()
                            }
                            .disabled(viewModel.isProcessing)
                        }
                    }
                    .font(.callout)
                }
            }

            HStack {
                Text(viewModel.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy") {
                    viewModel.copyRecognizedText()
                }
                .disabled(viewModel.recognizedText.isEmpty)
                Button("Clear") {
                    viewModel.clearText()
                }
                .disabled(viewModel.recognizedText.isEmpty)
            }

            HSplitView {
                GroupBox("История") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Picker(
                                "Профиль",
                                selection: Binding(
                                    get: { viewModel.selectedProfileID },
                                    set: { viewModel.selectProfile($0) }
                                )
                            ) {
                                ForEach(viewModel.profiles) { profile in
                                    Text(profile.name).tag(Optional(profile.id))
                                }
                            }
                            .labelsHidden()

                            Button {
                                newProfileName = ""
                                isCreateProfilePresented = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .help("Создать профиль")

                            Button(role: .destructive) {
                                isDeleteProfileConfirmationPresented = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .help("Удалить текущий профиль")
                            .disabled(!viewModel.canDeleteSelectedProfile)
                        }

                        if viewModel.history.isEmpty {
                            ContentUnavailableView(
                                "Пока пусто",
                                systemImage: "clock.arrow.circlepath",
                                description: Text("После захвата текста записи появятся здесь.")
                            )
                        } else {
                            List(
                                viewModel.history,
                                selection: Binding(
                                    get: { viewModel.selectedEntryID },
                                    set: { viewModel.selectEntry($0) }
                                )
                            ) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        Spacer(minLength: 8)
                                        Text(viewModel.formattedDate(for: item.createdAt))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(item.preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                                .tag(item.id)
                            }
                            .listStyle(.sidebar)
                        }
                    }
                }
                .frame(minWidth: 280, idealWidth: 320)

                GroupBox("Текст записи") {
                    if viewModel.selectedEntryID == nil {
                        ContentUnavailableView(
                            "Выберите запись",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Слева выберите элемент истории, чтобы открыть полный текст.")
                        )
                    } else {
                        TextEditor(
                            text: Binding(
                                get: { viewModel.recognizedText },
                                set: { viewModel.updateSelectedText($0) }
                            )
                        )
                        .font(.system(.body, design: .monospaced))
                    }
                }
                .frame(minWidth: 480)
            }
            .frame(minHeight: 320)
            .overlay {
                if viewModel.isProcessing {
                    ProgressView()
                }
            }
        }
        .padding(16)
        .frame(minWidth: 860, minHeight: 500)
        .sheet(isPresented: $isCreateProfilePresented) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Новый профиль")
                    .font(.headline)
                TextField("Название профиля", text: $newProfileName)
                HStack {
                    Spacer()
                    Button("Отмена") {
                        isCreateProfilePresented = false
                    }
                    Button("Создать") {
                        viewModel.createProfile(named: newProfileName)
                        isCreateProfilePresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 360)
        }
        .alert("Удалить профиль?", isPresented: $isDeleteProfileConfirmationPresented) {
            Button("Удалить", role: .destructive) {
                viewModel.deleteSelectedProfile()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Профиль \"\(viewModel.selectedProfileName)\" будет удален вместе со всей историей внутри него.")
        }
    }
}

#Preview {
    ContentView(viewModel: MainViewModel())
}
