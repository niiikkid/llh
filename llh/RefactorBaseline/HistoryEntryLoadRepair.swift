//
//  HistoryEntryLoadRepair.swift
//  llh
//
//  Phase 0: pure repair rules applied when loading history (see MainViewModel.loadHistory).
//

import Foundation

enum HistoryEntryLoadRepair {
    /// Normalizes a persisted entry after an interrupted app session (processing → failed, empty payloads cleared).
    static func repair(_ entry: CapturedTextEntry) -> CapturedTextEntry {
        var mutableEntry = entry
        if mutableEntry.formattedText?.hasContent == false {
            mutableEntry.formattedText = nil
        }
        if mutableEntry.formattedText == nil, mutableEntry.formattingStatus == .processing {
            mutableEntry.formattingStatus = .failed
        }
        if mutableEntry.formattedText != nil {
            mutableEntry.formattingStatus = .succeeded
        }
        if mutableEntry.studyMaterials.words?.hasContent == false { mutableEntry.studyMaterials.words = nil }
        if mutableEntry.studyMaterials.phrases?.hasContent == false { mutableEntry.studyMaterials.phrases = nil }
        if mutableEntry.studyMaterials.grammar?.hasContent == false { mutableEntry.studyMaterials.grammar = nil }
        if mutableEntry.studyMaterials.words == nil, mutableEntry.studyMaterials.wordsStatus == .processing {
            mutableEntry.studyMaterials.wordsStatus = .failed
        }
        if mutableEntry.studyMaterials.phrases == nil, mutableEntry.studyMaterials.phrasesStatus == .processing {
            mutableEntry.studyMaterials.phrasesStatus = .failed
        }
        if mutableEntry.studyMaterials.grammar == nil, mutableEntry.studyMaterials.grammarStatus == .processing {
            mutableEntry.studyMaterials.grammarStatus = .failed
        }
        return mutableEntry
    }

    static func repairProfile(_ profile: LearningProfile) -> LearningProfile {
        var mutableProfile = profile
        mutableProfile.history = mutableProfile.history.map(repair)
        return mutableProfile
    }
}
