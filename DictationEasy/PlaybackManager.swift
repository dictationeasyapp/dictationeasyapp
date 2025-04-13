import Foundation
import SwiftUI

@MainActor
class PlaybackManager: ObservableObject {
    @Published var sentences: [String] = []
    @Published var currentSentenceIndex: Int = 0
    @Published var currentRepetition: Int = 1
    @Published var isPlaying: Bool = false
    @Published var isShuffled: Bool = false
    @Published var error: String?

    private var originalSentences: [String] = []
    private var shuffledIndices: [Int] = []
    private var originalToShuffledIndices: [Int: Int] = [:]
    private var timer: Timer?
    private var ttsManager: TTSManagerProtocol?
    private var settings: SettingsModel?
    private var pendingWorkItem: DispatchWorkItem?

    func setSentences(_ text: String) {
        // Split text into paragraphs first
        let paragraphs = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Split each paragraph into sentences and flatten the result
        originalSentences = paragraphs.flatMap { $0.splitIntoSentences() }
        sentences = originalSentences
        shuffledIndices = Array(0..<originalSentences.count)
        originalToShuffledIndices.removeAll()
        currentSentenceIndex = 0
        currentRepetition = 1
        isShuffled = false
    }

    func shuffleSentences() {
        guard !sentences.isEmpty else { return }
        
        // Generate a shuffled list of indices
        var indices = Array(0..<originalSentences.count)
        indices.shuffle()
        shuffledIndices = indices
        
        // Map original indices to shuffled positions
        originalToShuffledIndices.removeAll()
        for (shuffledIndex, originalIndex) in indices.enumerated() {
            originalToShuffledIndices[originalIndex] = shuffledIndex
        }
        
        // Update sentences based on shuffled indices
        sentences = shuffledIndices.map { originalSentences[$0] }
        
        // Reset current sentence index to 0 so "Play" starts from the first sentence
        currentSentenceIndex = 0
        
        isShuffled = true
    }

    func restoreOriginalOrder() {
        guard !sentences.isEmpty else { return }
        
        // Restore original order
        sentences = originalSentences
        shuffledIndices = Array(0..<originalSentences.count)
        originalToShuffledIndices.removeAll()
        
        // Reset current sentence index to 0 so "Play" starts from the first sentence
        currentSentenceIndex = 0
        
        isShuffled = false
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

        // Process the sentence to include or exclude punctuation
        let processedText = settings.processTextForSpeech(currentSentence)

        // Set up completion handler before speaking
        self.ttsManager?.onSpeechCompletion = { [weak self] in
            guard let self = self, self.isPlaying else { return }
            
            // Schedule the next step after the pause duration using DispatchWorkItem
            let workItem = DispatchWorkItem { [weak self] in
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
            
            // Store the work item so it can be canceled later
            self.pendingWorkItem = workItem
            
            // Schedule the work item
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(settings.pauseDuration), execute: workItem)
        }

        // Start speaking the processed sentence
        ttsManager.speak(
            text: processedText,
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
        // Cancel any pending DispatchWorkItem
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
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
