//
//  InMemoryAITextRequestLogStore.swift
//  llh
//

import Combine
import Foundation

/// Session-only text AI logs. Not written to disk; API keys are never stored.
@MainActor
final class InMemoryAITextRequestLogStore: ObservableObject {
    static let defaultMaximumEntryCount = 200

    @Published private(set) var entries: [AITextRequestLogEntry] = []

    private let maximumEntryCount: Int

    init(maximumEntryCount: Int = InMemoryAITextRequestLogStore.defaultMaximumEntryCount) {
        self.maximumEntryCount = max(1, maximumEntryCount)
    }

    func record(_ entry: AITextRequestLogEntry) {
        entries.insert(entry, at: 0)
        if entries.count > maximumEntryCount {
            entries.removeLast(entries.count - maximumEntryCount)
        }
    }

    func clear() {
        entries.removeAll()
    }

    /// Sendable façade so Data-layer clients can record without hopping onto MainActor themselves.
    nonisolated var asLogger: some AITextRequestLogging {
        AITextRequestLogSink { entry in
            Task { @MainActor [weak self] in
                self?.record(entry)
            }
        }
    }
}

struct AITextRequestLogSink: AITextRequestLogging {
    let recordEntry: @Sendable (AITextRequestLogEntry) -> Void

    func record(_ entry: AITextRequestLogEntry) {
        recordEntry(entry)
    }
}
