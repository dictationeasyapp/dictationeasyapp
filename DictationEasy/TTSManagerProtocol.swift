import Foundation

@MainActor
protocol TTSManagerProtocol {
    func speak(text: String, language: AudioLanguage, rate: Double)
    func stopSpeaking()
    func pauseSpeaking()
    func continueSpeaking()
}
