//
//  MicrophoneRecording.swift
//  llh
//

import Foundation

protocol MicrophoneRecording: AnyObject {
    func requestPermission() async -> Bool
    func startRecording() throws
    func stopRecording() throws -> Data
    func cancelRecording()
}
