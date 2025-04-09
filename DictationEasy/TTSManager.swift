import Foundation
import AVFoundation
import SwiftUI

@MainActor
class TTSManager: NSObject, ObservableObject, TTSManagerProtocol {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isPlaying: Bool = false
    @Published var error: String?
    
    var onSpeechCompletion: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, language: AudioLanguage, rate: Double) {
        guard !text.isEmpty else {
            error = "No text to speak 沒有文字可朗讀"
            return
        }

        guard let voice = AVSpeechSynthesisVoice(language: language.voiceIdentifier) else {
            error = "Selected voice is not available. Please download it in Settings > Accessibility > Spoken Content > Voices 所選語音不可用，請在設置 > 輔助功能 > 語音內容 > 語音中下載"
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Float(rate) * AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
        isPlaying = true
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
    }

    func pauseSpeaking() {
        synthesizer.pauseSpeaking(at: .immediate)
        isPlaying = false
    }

    func continueSpeaking() {
        synthesizer.continueSpeaking()
        isPlaying = true
    }
}

extension TTSManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
            self.onSpeechCompletion?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = true
        }
    }
}
