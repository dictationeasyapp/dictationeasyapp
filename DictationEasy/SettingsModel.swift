import Foundation
import AVFoundation

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
    @Published var pauseDuration: Int = 2
    @Published var repetitions: Int = 1
    @Published var showText: Bool = true
    @Published var extractedText: String = ""
    @Published var sentences: [String] = []

    func isSelectedVoiceAvailable() -> Bool {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.contains { $0.language == audioLanguage.voiceIdentifier }
    }
}
