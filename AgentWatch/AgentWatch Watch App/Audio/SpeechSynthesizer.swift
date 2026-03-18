// SpeechSynthesizer.swift
// AVSpeechSynthesizer wrapper. Enqueues text chunks for playback as they arrive,
// overlapping decode and speak for low-latency streaming TTS.
// PLATFORM NOTE: Requires watchOS/iOS. Not compilable on Linux.

import Foundation
#if canImport(AVFoundation)
import AVFoundation

@MainActor
final class SpeechSynthesizer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    @Published private(set) var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingChunks: [String] = []
    private var voiceRate: Float = AVSpeechUtteranceDefaultSpeechRate
    private var voicePitch: Float = 1.0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public API

    func configure(rate: Double, pitch: Double) {
        voiceRate = Float(rate) * AVSpeechUtteranceMaximumSpeechRate
        voicePitch = Float(pitch)
    }

    /// Enqueue a text chunk for playback. Starts speaking immediately if idle.
    func enqueueChunk(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = voiceRate
        utterance.pitchMultiplier = voicePitch
        utterance.preUtteranceDelay = 0
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                        didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking {
                self.isSpeaking = false
            }
        }
    }
}
#endif
