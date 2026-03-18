// SpeechRecorder.swift
// On-device speech recognition via SFSpeechRecognizer + AVAudioEngine.
// Audio never leaves the device; only the transcribed text string is used.
// PLATFORM NOTE: Requires watchOS. Not compilable on Linux (no Speech framework).

import Foundation
#if canImport(Speech)
import Speech
import AVFoundation

@MainActor
final class SpeechRecorder: NSObject, ObservableObject {

    enum RecordingState {
        case idle
        case recording
        case done(transcript: String)
        case failed(Error)
    }

    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var partialTranscript: String = ""

    private let recognizer = SFSpeechRecognizer(locale: .current)
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    // MARK: - Public API

    func requestPermission() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        let audioStatus = await AVAudioApplication.requestRecordPermission()
        return audioStatus
    }

    func startRecording() {
        guard case .idle = state else { return }
        guard recognizer?.isAvailable == true else {
            state = .failed(RecorderError.recognizerUnavailable)
            return
        }

        do {
            try beginSession()
            state = .recording
        } catch {
            state = .failed(error)
        }
    }

    func stopRecording() {
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        state = .idle
    }

    // MARK: - Private

    private func beginSession() throws {
        let engine = AVAudioEngine()
        audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true   // Privacy: on-device only
        recognitionRequest = request

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try engine.start()

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.partialTranscript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.state = .done(transcript: result.bestTranscription.formattedString)
                        self.audioEngine?.stop()
                    }
                }
            } else if let error {
                Task { @MainActor in
                    self.state = .failed(error)
                }
            }
        }
    }

    enum RecorderError: LocalizedError {
        case recognizerUnavailable
        var errorDescription: String? { "Speech recognizer not available. Try again." }
    }
}
#endif
