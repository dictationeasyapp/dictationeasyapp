import SwiftUI
import AVFoundation

// String extension for sentence splitting
extension String {
    func splitIntoSentences() -> [String] {
        // Define sentence-ending punctuation
        let punctuationSet = CharacterSet(charactersIn: ".!?。！？")
        
        // Split the string into components based on punctuation followed by whitespace
        var sentences: [String] = []
        var currentSentence = ""
        
        var characters = self[...]
        while !characters.isEmpty {
            // Find the next punctuation mark
            if let range = characters.unicodeScalars.firstIndex(where: { punctuationSet.contains($0) }) {
                // Include the punctuation in the sentence
                let endIndex = characters.index(after: range)
                currentSentence += String(characters[..<endIndex])
                
                // Move past the punctuation
                characters = characters[endIndex...]
                
                // Look for whitespace after the punctuation
                if let nextNonWhitespace = characters.unicodeScalars.firstIndex(where: { !CharacterSet.whitespacesAndNewlines.contains($0) }) {
                    // If there's whitespace followed by more text, this is a sentence boundary
                    sentences.append(currentSentence.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentSentence = ""
                    characters = characters[nextNonWhitespace...]
                } else {
                    // If there's no more text after the punctuation, include remaining whitespace in the sentence
                    currentSentence += String(characters)
                    characters = Substring()
                }
            } else {
                // No more punctuation; the remaining text is the last sentence
                currentSentence += String(characters)
                characters = Substring()
            }
        }
        
        // Add the last sentence if it exists
        if !currentSentence.isEmpty {
            sentences.append(currentSentence.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // Filter out empty sentences
        return sentences.filter { !$0.isEmpty }
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

struct DictationEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let text: String
    
    init(id: UUID = UUID(), date: Date = Date(), text: String) {
        self.id = id
        self.date = date
        self.text = text
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
    @Published var pastDictations: [DictationEntry] = []
    @Published var editingDictationId: UUID? = nil
    @Published var error: String?
    
    private let pastDictationsFileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pastDictations.json")
    }()
    
    init() {
        loadPastDictations()
    }
    
    private func updateSentences() {
        let paragraphs = extractedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        sentences = paragraphs.flatMap { $0.splitIntoSentences() }
    }

    func isSelectedVoiceAvailable() -> Bool {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.contains { $0.language == audioLanguage.voiceIdentifier }
    }
    
    func processTextForSpeech(_ text: String) -> String {
        guard includePunctuation else {
            return text.replacingOccurrences(of: "[.!?。！？⋯⋯,，:：;；]", with: "", options: .regularExpression)
        }

        var processedText = text
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
        
        for (mark, description) in punctuationMappings {
            processedText = processedText.replacingOccurrences(
                of: mark,
                with: description,
                options: .regularExpression
            )
        }
        return processedText.trimmingCharacters(in: .whitespaces)
    }
    
    func loadPastDictations() {
        if let data = try? Data(contentsOf: pastDictationsFileURL),
           let decoded = try? JSONDecoder().decode([DictationEntry].self, from: data) {
            self.pastDictations = decoded
        }
    }
    
    func savePastDictation(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        #if DEBUG
        print("SettingsModel.savePastDictation - Current editingDictationId: \(String(describing: editingDictationId))")
        #endif
        
        if let editingId = editingDictationId {
            #if DEBUG
            print("SettingsModel.savePastDictation - Removing original entry with id: \(editingId)")
            #endif
            deletePastDictation(id: editingId)
        }
        
        let entry = DictationEntry(text: trimmedText)
        pastDictations.insert(entry, at: 0)
        
        if let encoded = try? JSONEncoder().encode(pastDictations) {
            do {
                try encoded.write(to: pastDictationsFileURL, options: [.atomic, .completeFileProtection])
            } catch {
                print("Failed to save past dictations: \(error)")
                self.error = "Failed to save dictation: \(error.localizedDescription) 無法保存文章：\(error.localizedDescription)"
            }
        }
        
        #if DEBUG
        print("SettingsModel.savePastDictation - Saved new entry with id: \(entry.id)")
        #endif
        
        editingDictationId = nil
        
        #if DEBUG
        print("SettingsModel.savePastDictation - Cleared editingDictationId")
        #endif
    }
    
    func deletePastDictation(id: UUID) {
        pastDictations.removeAll { $0.id == id }
        
        if let encoded = try? JSONEncoder().encode(pastDictations) {
            do {
                try encoded.write(to: pastDictationsFileURL, options: [.atomic, .completeFileProtection])
            } catch {
                print("Failed to save past dictations after deletion: \(error)")
                self.error = "Failed to delete dictation: \(error.localizedDescription) 無法刪除文章：\(error.localizedDescription)"
            }
        }
    }
    
    func deleteAllPastDictations() {
        #if DEBUG
        print("SettingsModel.deleteAllPastDictations - Deleting all past dictations")
        #endif
        
        pastDictations = []
        
        if let encoded = try? JSONEncoder().encode(pastDictations) {
            do {
                try encoded.write(to: pastDictationsFileURL, options: [.atomic, .completeFileProtection])
                #if DEBUG
                print("SettingsModel.deleteAllPastDictations - Successfully deleted all entries")
                #endif
            } catch {
                print("SettingsModel.deleteAllPastDictations - Failed to save empty array: \(error)")
                self.error = "Failed to delete all dictations: \(error.localizedDescription) 無法刪除所有文章：\(error.localizedDescription)"
            }
        } else {
            #if DEBUG
            print("SettingsModel.deleteAllPastDictations - Failed to encode empty array")
            #endif
            self.error = "Failed to delete all dictations: Unable to encode data 無法刪除所有文章：無法編碼數據"
        }
        
        // Clear any editing state
        editingDictationId = nil
    }
}
