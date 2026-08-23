//
//  AVAudioMicrophoneRecorder.swift
//  llh
//

import AVFAudio
import CoreAudioTypes
import Foundation

/// Records a bounded m4a clip for file transcription. Temporary file is deleted after stop/cancel.
final class AVAudioMicrophoneRecorder: MicrophoneRecording {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws {
        cancelRecording()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("llh-overlay-chat-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = false
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
}
