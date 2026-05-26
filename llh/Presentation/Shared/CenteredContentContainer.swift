//
//  CenteredContentContainer.swift
//  llh
//

import SwiftUI

struct CenteredContentContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
