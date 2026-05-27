//
//  MainChromeView.swift
//  llh
//

import SwiftUI

struct MainChromeView: View {
    @ObservedObject var settings: SettingsViewModel
    @Binding var route: AppMainRoute
    @Binding var isTranslationsSidebarCollapsed: Bool
    var canReturnToWorkspace: Bool
    var onNavigate: (AppMainRoute) -> Void

    var body: some View {
        HStack {
            if route == .settings {
                Button {
                    onNavigate(.workspace)
                } label: {
                    Label("Назад", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
            } else if route == .sessions {
                Button {
                    onNavigate(.workspace)
                } label: {
                    Label("К переводам", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .disabled(!canReturnToWorkspace)
            } else {
                Button {
                    onNavigate(.sessions)
                } label: {
                    Image(systemName: "rectangle.stack")
                }
                .buttonStyle(.bordered)
                .help("Все сессии")
            }

            Text(chromeTitle)
                .font(.title3.weight(.semibold))
                .lineLimit(1)

            Spacer()

            if route == .workspace {
                HStack(spacing: 8) {
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
                    .fixedSize(horizontal: true, vertical: false)
                    .help("Движок OCR: \(settings.selectedOCREngine.title)")
                    .accessibilityLabel("Движок OCR")

                    Button {
                        isTranslationsSidebarCollapsed.toggle()
                    } label: {
                        Image(
                            systemName: isTranslationsSidebarCollapsed
                                ? "sidebar.left"
                                : "sidebar.leading"
                        )
                    }
                    .buttonStyle(.bordered)
                    .help(
                        isTranslationsSidebarCollapsed
                            ? "Показать список переводов"
                            : "Скрыть список переводов"
                    )
                }
            }

            if route != .settings {
                Button {
                    onNavigate(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
                .help("Настройки")
            }
        }
    }

    private var chromeTitle: String {
        switch route {
        case .sessions:
            return "Сессии"
        case .workspace:
            return AppDisplayStrings.productName
        case .settings:
            return "Настройки"
        }
    }
}
