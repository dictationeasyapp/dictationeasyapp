import SwiftUI
import AVFoundation

// String extension for sentence splitting
extension String {
    func splitIntoSentences() -> [String] {
        // Define punctuation patterns
        let englishPunctuation = "[.!?]"
        let chinesePunctuation = "[。！？⋯⋯]" // Fixed to use two ellipsis characters
        let quotesAndParens = "[\"'()（）]"   // Fixed quote escaping
        
        // Pattern to match sentences:
        // 1. Look for punctuation (English or Chinese)
        // 2. Optionally followed by quotes or parentheses
        // 3. Followed by whitespace or end of string
        let pattern = "([^\(englishPunctuation)\(chinesePunctuation)]+[\(englishPunctuation)\(chinesePunctuation)]+[\(quotesAndParens)]*\\s*)" // Allow multiple punctuation marks
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            // If regex fails, return the whole text as one sentence
            return [self].filter { !$0.isEmpty }
        }
        
        let nsString = self as NSString
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var sentences: [String] = []
        var lastEnd = 0
        
        // Extract sentences from matches
        for match in matches {
            let range = match.range(at: 1)
            let sentence = nsString.substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            lastEnd = range.location + range.length
        }
        
        // Handle any remaining text after the last punctuation
        if lastEnd < nsString.length {
            let remainingText = nsString.substring(from: lastEnd)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !remainingText.isEmpty {
                sentences.append(remainingText)
            }
        }
        
        // If no sentences were found, return the original text as one sentence
        return sentences.isEmpty ? [self].filter { !$0.isEmpty } : sentences
    }
}

enum PlaybackMode: String, CaseIterable {
    case wholePassage = "Whole Passage 整段"
    case sentenceBySentence = "Sentence by Sentence 逐句"
    case teacherMode = "Teacher Mode 老師模式"
}

enum AudioLanguage: String, CaseIterable {
    case english = "English 英語"
    case mandarin = "Mandarin 普通話"
    case cantonese = "Cantonese 廣東話"

    var voiceIdentifier: String {
        switch self {
        case .english:
            return "en-US"
        case .mandarin:
            return "zh-CN"
        case .cantonese:
            return "zh-HK"
        }
    }
}

@MainActor
class SettingsModel: ObservableObject {
    @Published var playbackMode: PlaybackMode = .wholePassage
    @Published var audioLanguage: AudioLanguage = .english
    @Published var playbackSpeed: Double = 1.0
    @Published var pauseDuration: Int = 5
    @Published var repetitions: Int = 2
    @Published var showText: Bool = true
    @Published var includePunctuation: Bool = false
    @Published var extractedText: String = "" {
        didSet {
            updateSentences()
        }
    }
    @Published var sentences: [String] = []

    private func updateSentences() {
        // Split text into paragraphs first
        let paragraphs = extractedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Split each paragraph into sentences and flatten the result
        sentences = paragraphs.flatMap { $0.splitIntoSentences() }
    }

    func isSelectedVoiceAvailable() -> Bool {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.contains { $0.language == audioLanguage.voiceIdentifier }
    }

    // Helper method to process text for audio playback
    func processTextForSpeech(_ text: String) -> String {
        guard includePunctuation else {
            // If punctuation is not included, strip all punctuation marks
            return text.replacingOccurrences(of: "[.!?。！？⋯⋯,，:：;；]", with: "", options: .regularExpression)
        }

        var processedText = text

        // Define punctuation mappings based on language
        let punctuationMappings: [(String, String)] = {
            switch audioLanguage {
            case .english:
                return [
                    ("\\.", " full stop "),
                    ("!", " exclamation mark "),
                    ("\\?", " question mark "),
                    (",", " comma "),
                    (":", " colon "),
                    (";", " semicolon ")
                ]
            case .mandarin, .cantonese:
                return [
                    ("。", " 句號 "),
                    ("！", " 感嘆號 "),
                    ("？", " 問號 "),
                    ("，", " 逗號 "),
                    ("：", " 冒號 "),
                    ("；", " 分號 "),
                    ("⋯⋯", " 省略號 ")
                ]
            }
        }()

        // Replace each punctuation mark with its spoken description
        for (mark, description) in punctuationMappings {
            processedText = processedText.replacingOccurrences(
                of: mark,
                with: description,
                options: .regularExpression
            )
        }

        return processedText.trimmingCharacters(in: .whitespaces)
    }
}
