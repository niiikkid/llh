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
            Text(AppDisplayStrings.productName)
                .font(.title3.weight(.semibold))
            Spacer()
            Picker(
                "",
                selection: Binding(
                    get: { settings.selectedOCREngine },
                    set: { settings.selectOCREngine($0) }
                )
            ) {
                ForEach(OCREngine.allCases) { engine in
                    Text(engine.title).tag(engine)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 200)
            .help("Движок OCR: \(settings.selectedOCREngine.title)")
            .accessibilityLabel("Движок OCR")

            Button {
                isSessionsPanelCollapsed.toggle()
            } label: {
                Image(
                    systemName: isSessionsPanelCollapsed ? "sidebar.left" : "sidebar.leading"
                )
            }
            .buttonStyle(.bordered)
            .help(isSessionsPanelCollapsed ? "Показать сессии" : "Скрыть сессии")

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
            .help("Настройки")
        }
    }
}
