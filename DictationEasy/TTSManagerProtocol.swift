import Foundation

@MainActor
protocol TTSManagerProtocol {
    var onSpeechCompletion: (() -> Void)? { get set }
    func speak(text: String, language: AudioLanguage, rate: Double)
    func stopSpeaking()
    func pauseSpeaking()
    func continueSpeaking()
}
