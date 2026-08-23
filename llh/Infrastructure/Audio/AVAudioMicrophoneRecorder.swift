//
//  AVAudioMicrophoneRecorder.swift
//  llh
//

import AVFoundation
import AppKit
import CoreAudioTypes
import Foundation

/// Records a bounded WAV clip for file transcription. Temporary file is deleted after stop/cancel.
///
/// Sandboxed macOS needs `com.apple.security.device.microphone`. TCC permission is requested
/// via `AVCaptureDevice`, not `AVAudioApplication`.
final class AVAudioMicrophoneRecorder: MicrophoneRecording {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            // Overlay is nonactivating; the system prompt needs the app visible.
            NSApp.activate(ignoringOtherApps: true)
            return await AVCaptureDevice.requestAccess(for: .audio)
        @unknown default:
            return await AVCaptureDevice.requestAccess(for: .audio)
        }
    }

    func startRecording() throws {
        cancelRecording()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("llh-overlay-chat-\(UUID().uuidString).wav")

        do {
            let recorder = try AVAudioRecorder(url: url, settings: Self.linearPCMSettings)
            guard recorder.prepareToRecord() else {
                try? FileManager.default.removeItem(at: url)
                throw MicrophoneRecordingError.recordingFailed
            }
            guard recorder.record() else {
                try? FileManager.default.removeItem(at: url)
                throw MicrophoneRecordingError.recordingFailed
            }
            self.recorder = recorder
            self.fileURL = url
        } catch let error as MicrophoneRecordingError {
            throw error
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw MicrophoneRecordingError.recordingFailed
        }
    }

    func stopRecording() throws -> Data {
        recorder?.stop()
        defer { cleanup() }

        guard let fileURL else {
            throw MicrophoneRecordingError.noAudioRecorded
        }
        let data = try Data(contentsOf: fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        guard !data.isEmpty else {
            throw MicrophoneRecordingError.noAudioRecorded
        }
        return data
    }

    func cancelRecording() {
        recorder?.stop()
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        cleanup()
    }

    private func cleanup() {
        recorder = nil
        fileURL = nil
    }

    /// Linear PCM is the reliable macOS path; AAC 16 kHz often makes `record()` return false.
    private static let linearPCMSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]
}
