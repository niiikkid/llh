//
//  CaptureProcessingOverlay.swift
//  llh
//

import SwiftUI

struct CaptureProcessingOverlay: ViewModifier {
    let isProcessing: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isProcessing {
                ProgressView()
            }
        }
    }
}

extension View {
    func captureProcessingOverlay(isProcessing: Bool) -> some View {
        modifier(CaptureProcessingOverlay(isProcessing: isProcessing))
    }
}
