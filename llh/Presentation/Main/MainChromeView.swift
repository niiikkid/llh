//
//  MainChromeView.swift
//  llh
//

import SwiftUI

struct MainChromeView: View {
    @ObservedObject var settings: SettingsViewModel
    @Binding var isSessionsPanelCollapsed: Bool
    @Binding var isSettingsPresented: Bool

    var body: some View {
        HStack {
            Text("Language Learning Helper")
                .font(.title3.weight(.semibold))
            Spacer()
            Picker(
                "Движок OCR",
                selection: Binding(
                    get: { settings.selectedOCREngine },
                    set: { settings.selectOCREngine($0) }
                )
            ) {
                ForEach(OCREngine.allCases) { engine in
                    Text(engine.title).tag(engine)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            Button {
                isSessionsPanelCollapsed.toggle()
            } label: {
                Label(
                    isSessionsPanelCollapsed ? "Показать сессии" : "Скрыть сессии",
                    systemImage: isSessionsPanelCollapsed ? "sidebar.left" : "sidebar.leading"
                )
            }
            .buttonStyle(.bordered)
            Button {
                isSettingsPresented = true
            } label: {
                Label("Настройки", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
        }
    }
}
