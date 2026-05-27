//
//  SessionAutomationTogglesView.swift
//  llh
//

import SwiftUI

struct SessionAutomationTogglesView: View {
    @Binding var loadWords: Bool
    @Binding var loadGrammar: Bool
    @Binding var showWordsInCompactOverlay: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Автоматически переводить слова", isOn: $loadWords)
            Toggle("Автоматически объяснять грамматику", isOn: $loadGrammar)
            Toggle("Показывать перевод слов в компактном окне", isOn: $showWordsInCompactOverlay)
        }
    }
}
