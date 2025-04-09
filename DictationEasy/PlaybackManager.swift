import Foundation
import SwiftUI

@MainActor
class PlaybackManager: ObservableObject {
    @Published var sentences: [String] = []
    @Published var currentSentenceIndex: Int = 0
    @Published var currentRepetition: Int = 1
    @Published var isPlaying: Bool = false
    @Published var error: String?

    private var timer: Timer?
    private var ttsManager: TTSManagerProtocol?
    private var settings: SettingsModel?

    func setSentences(_ text: String) {
        // Split text into paragraphs first
        let paragraphs = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Split each paragraph into sentences and flatten the result
        sentences = paragraphs.flatMap { $0.splitIntoSentences() }
        currentSentenceIndex = 0
        currentRepetition = 1
    }

    func getCurrentSentence() -> String? {
        guard !sentences.isEmpty, currentSentenceIndex < sentences.count else {
            return nil
        }
        return sentences[currentSentenceIndex]
    }

    func nextSentence() -> String? {
        guard !sentences.isEmpty else { return nil }
        let nextIndex = currentSentenceIndex + 1
        if nextIndex < sentences.count {
            currentSentenceIndex = nextIndex
            currentRepetition = 1
            return getCurrentSentence()
        }
        // In Teacher Mode, don't loop back to the beginning
        if let settings = settings, settings.playbackMode == .teacherMode {
            return nil
        }
        // In other modes, loop back to the beginning
        currentSentenceIndex = 0
        currentRepetition = 1
        return getCurrentSentence()
    }

    func previousSentence() -> String? {
        guard !sentences.isEmpty else { return nil }
        currentSentenceIndex = currentSentenceIndex > 0 ? currentSentenceIndex - 1 : sentences.count - 1
        currentRepetition = 1
        return getCurrentSentence()
    }

    func startTeacherMode(ttsManager: TTSManagerProtocol, settings: SettingsModel) {
        guard getCurrentSentence() != nil else {
            error = "No text available 沒有文字可播放"
            return
        }

        self.ttsManager = ttsManager
        self.settings = settings
        isPlaying = true
        playCurrentSentence()
    }

    private func playCurrentSentence() {
        guard isPlaying,
              let currentSentence = getCurrentSentence(),
              let settings = settings else { return }
        
        guard let ttsManager = self.ttsManager else { return }

        // Set up completion handler before speaking
        self.ttsManager?.onSpeechCompletion = { [weak self] in
            guard let self = self, self.isPlaying else { return }
            
            // Schedule the next step after the pause duration
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(settings.pauseDuration)) {
                Task { @MainActor [weak self] in
                    guard let self = self, self.isPlaying else { return }
                    
                    if self.currentRepetition < settings.repetitions {
                        self.currentRepetition += 1
                        self.playCurrentSentence()
                    } else {
                        if self.nextSentence() != nil {
                            self.currentRepetition = 1
                            self.playCurrentSentence()
                        } else {
                            self.stopPlayback()
                        }
                    }
                }
            }
        }

        // Start speaking the current sentence
        ttsManager.speak(
            text: currentSentence,
            language: settings.audioLanguage,
            rate: settings.playbackSpeed
        )
    }

    func stopPlayback() {
        isPlaying = false
        self.ttsManager?.stopSpeaking()
        self.ttsManager?.onSpeechCompletion = nil
        timer?.invalidate()
        timer = nil
        currentRepetition = 1
        ttsManager = nil
        settings = nil
    }

    func getProgressText() -> String {
        guard !sentences.isEmpty else { return "No sentences available 沒有句子可播放" }
        guard let settings = settings else { return "Settings not available 設置不可用" }

        if settings.playbackMode == .teacherMode {
            return "Sentence 句子 \(currentSentenceIndex + 1) of 共 \(sentences.count) (Reading 朗讀 \(currentRepetition) of 共 \(settings.repetitions))"
        } else {
            return "Sentence 句子 \(currentSentenceIndex + 1) of 共 \(sentences.count)"
        }
    }
}
