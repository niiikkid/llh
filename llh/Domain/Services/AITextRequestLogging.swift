//
//  AITextRequestLogging.swift
//  llh
//

import Foundation

/// Records text completions (prompts, model, response). Must never receive API keys.
protocol AITextRequestLogging: Sendable {
    func record(_ entry: AITextRequestLogEntry)
}
