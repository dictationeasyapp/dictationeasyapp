import SwiftUI

struct SpeechTabView: View {
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var ttsManager: TTSManager
    @EnvironmentObject var playbackManager: PlaybackManager

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Text Display Toggle
                Toggle("Show Text 顯示文字", isOn: $settings.showText)
                    .padding(.horizontal)

                // Punctuation Toggle
                Toggle("Including Punctuations 包含標點符號", isOn: $settings.includePunctuation)
                    .padding(.horizontal)

                // Text Display
                if settings.showText {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(settings.sentences.enumerated()), id: \.offset) { index, sentence in
                                    Text(sentence)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            shouldHighlightSentence(index: index)
                                                ? Color.yellow.opacity(0.3)
                                                : Color.clear
                                        )
                                        .cornerRadius(8)
                                        .id(index)  // Add id for scrolling
                                }
                            }
                            .padding()
                        }
                        .frame(maxHeight: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .onChange(of: playbackManager.currentSentenceIndex) { newIndex in
                            if settings.showText &&
                               playbackManager.isPlaying &&
                               (settings.playbackMode == .teacherMode || settings.playbackMode == .sentenceBySentence) {
                                withAnimation {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }

                // Playback Mode Picker
                Picker("Mode 模式", selection: $settings.playbackMode) {
                    ForEach(PlaybackMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Teacher Mode Settings
                if settings.playbackMode == .teacherMode {
                    VStack(spacing: 10) {
                        Stepper("Pause Duration 暫停時間: \(settings.pauseDuration)s",
                                value: $settings.pauseDuration,
                                in: 1...10)

                        Stepper("Repetitions 重複次數: \(settings.repetitions)",
                                value: $settings.repetitions,
                                in: 1...5)
                    }
                    .padding(.horizontal)
                }

                // Speed Slider
                VStack(alignment: .leading) {
                    Text("Speed 速度: \(String(format: "%.2f", settings.playbackSpeed))x")
                    Slider(value: $settings.playbackSpeed,
                           in: 0.05...1.0,
                           step: 0.05)
                }
                .padding(.horizontal)

                // Language Picker
                Picker("Language 語言", selection: $settings.audioLanguage) {
                    ForEach(AudioLanguage.allCases, id: \.self) { language in
                        Text(language.rawValue).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                // Playback Controls
                HStack(spacing: 20) {
                    // Play/Stop Button
                    Button(action: {
                        if playbackManager.isPlaying {
                            playbackManager.stopPlayback()
                            ttsManager.stopSpeaking()
                        } else {
                            switch settings.playbackMode {
                            case .wholePassage:
                                playbackManager.isPlaying = true
                                ttsManager.speak(
                                    text: settings.processTextForSpeech(settings.sentences.joined(separator: " ")),
                                    language: settings.audioLanguage,
                                    rate: settings.playbackSpeed
                                )
                            case .sentenceBySentence:
                                if let sentence = playbackManager.getCurrentSentence() {
                                    playbackManager.isPlaying = true
                                    ttsManager.speak(
                                        text: settings.processTextForSpeech(sentence),
                                        language: settings.audioLanguage,
                                        rate: settings.playbackSpeed
                                    )
                                }
                            case .teacherMode:
                                playbackManager.startTeacherMode(ttsManager: ttsManager, settings: settings)
                            }
                        }
                    }) {
                        Label(playbackManager.isPlaying ? "Stop 停止" : "Play 播放",
                              systemImage: playbackManager.isPlaying ? "stop.fill" : "play.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(settings.sentences.isEmpty)

                    // Restart Button (Whole Passage mode only)
                    if settings.playbackMode == .wholePassage {
                        Button(action: {
                            ttsManager.stopSpeaking()
                            playbackManager.isPlaying = true
                            ttsManager.speak(
                                text: settings.processTextForSpeech(settings.sentences.joined(separator: " ")),
                                language: settings.audioLanguage,
                                rate: settings.playbackSpeed
                            )
                        }) {
                            Label("Restart 重新開始", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(settings.sentences.isEmpty)
                    }

                    // Restart Button (Teacher Mode only)
                    if settings.playbackMode == .teacherMode {
                        Button(action: {
                            playbackManager.currentSentenceIndex = 0
                            playbackManager.startTeacherMode(ttsManager: ttsManager, settings: settings)
                        }) {
                            Label("Restart 重新開始", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }

                    // Navigation Buttons (Sentence by Sentence mode only)
                    if settings.playbackMode == .sentenceBySentence {
                        Button(action: {
                            if let sentence = playbackManager.previousSentence() {
                                playbackManager.isPlaying = true
                                ttsManager.speak(
                                    text: settings.processTextForSpeech(sentence),
                                    language: settings.audioLanguage,
                                    rate: settings.playbackSpeed
                                )
                            }
                        }) {
                            Label("Previous 上一句", systemImage: "backward.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }

                        Button(action: {
                            if let sentence = playbackManager.nextSentence() {
                                playbackManager.isPlaying = true
                                ttsManager.speak(
                                    text: settings.processTextForSpeech(sentence),
                                    language: settings.audioLanguage,
                                    rate: settings.playbackSpeed
                                )
                            }
                        }) {
                            Label("Next 下一句", systemImage: "forward.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)

                // Progress Text
                Text(playbackManager.getProgressText())
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Voice Availability Warning
                if !settings.isSelectedVoiceAvailable() {
                    Text("Please download the \(settings.audioLanguage.rawValue) voice in Settings > Accessibility > Spoken Content > Voices 請在設置 > 輔助功能 > 語音內容 > 語音中下載\(settings.audioLanguage.rawValue)語音")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Spacer()
            }
            .navigationTitle("Speech 朗讀")
            .onChange(of: settings.playbackMode) { newMode in
                playbackManager.stopPlayback()
                ttsManager.stopSpeaking()
                if newMode == .teacherMode {
                    playbackManager.currentSentenceIndex = 0
                }
            }
            .onAppear {
                playbackManager.setSentences(settings.extractedText)
            }
        }
    }

    private func shouldHighlightSentence(index: Int) -> Bool {
        guard playbackManager.isPlaying else { return false }
        guard settings.playbackMode != .wholePassage else { return false }
        return index == playbackManager.currentSentenceIndex
    }
}

#Preview {
    SpeechTabView()
        .environmentObject(SettingsModel())
        .environmentObject(TTSManager())
        .environmentObject(PlaybackManager())
}
