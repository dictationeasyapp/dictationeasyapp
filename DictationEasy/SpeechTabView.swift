import SwiftUI

struct SpeechTabView: View {
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var ttsManager: TTSManager
    @EnvironmentObject var playbackManager: PlaybackManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var showUpgradePrompt = false // For upgrade prompt
    @State private var showSubscriptionView = false // For presenting SubscriptionView
    
    var isFreeUser: Bool {
        return !subscriptionManager.isPremium
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    togglesSection
                    textDisplaySection
                    playbackModePickerSection
                    teacherModeSettingsSection
                    speedSliderSection
                    languagePickerSection
                    playbackControlsSection
                    progressTextSection
                    voiceAvailabilityWarningSection
                    bannerAdSection
                }
            }
            .navigationTitle("Speech 朗讀")
            .onChange(of: settings.playbackMode) { newMode in
                playbackManager.stopPlayback()
                ttsManager.stopSpeaking()
                if newMode == .teacherMode {
                    playbackManager.currentSentenceIndex = 0
                } else if newMode == .wholePassage {
                    if playbackManager.isShuffled {
                        playbackManager.restoreOriginalOrder()
                    }
                }
            }
            .onAppear {
                playbackManager.setSentences(settings.extractedText)
            }
            .onChange(of: settings.extractedText) { _ in
                playbackManager.stopPlayback()
                ttsManager.stopSpeaking()
                playbackManager.setSentences(settings.extractedText)
            }
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView()
                    .environmentObject(subscriptionManager)
            }
            .alert("Upgrade to Premium 升級到高級版", isPresented: $showUpgradePrompt) {
                Button("Upgrade 升級", role: .none) {
                    showSubscriptionView = true
                }
                Button("Cancel 取消", role: .cancel) { }
            } message: {
                Text("Unlock this feature and more with a Premium subscription! 通過高級訂閱解鎖此功能等更多功能！")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var togglesSection: some View {
        VStack(spacing: 20) {
            Toggle("Show Text 顯示文字", isOn: $settings.showText)
                .padding(.horizontal)
            
            Toggle("Including Punctuations 包含標點符號", isOn: $settings.includePunctuation)
                .onChange(of: settings.includePunctuation) { newValue in
                    if newValue && !subscriptionManager.isPremium {
                        showUpgradePrompt = true
                        settings.includePunctuation = false // Revert the change
                    }
                }
                .padding(.horizontal)
        }
    }
    
    private var textDisplaySection: some View {
        Group {
            if settings.showText {
                // Random Order Button (moved above ScrollView)
                if settings.playbackMode != .wholePassage {
                    Button(action: {
                        if subscriptionManager.isPremium {
                            playbackManager.stopPlayback()
                            ttsManager.stopSpeaking()
                            if playbackManager.isShuffled {
                                playbackManager.restoreOriginalOrder()
                            } else {
                                playbackManager.shuffleSentences()
                            }
                        } else {
                            showUpgradePrompt = true
                        }
                    }) {
                        Label(playbackManager.isShuffled ? "Restore Order 恢復原序" : "Random 隨機調亂次序",
                              systemImage: playbackManager.isShuffled ? "arrow.clockwise" : "shuffle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(settings.sentences.isEmpty)
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(playbackManager.sentences.enumerated()), id: \.offset) { index, sentence in
                                Text(sentence)
                                    .font(.system(size: settings.fontSize))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        shouldHighlightSentence(index: index)
                                            ? Color.yellow.opacity(0.3)
                                            : Color.clear
                                    )
                                    .cornerRadius(8)
                                    .id(index)
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
        }
    }
    
    private var playbackModePickerSection: some View {
        Picker("Mode 模式", selection: $settings.playbackMode) {
            ForEach(PlaybackMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    private var teacherModeSettingsSection: some View {
        Group {
            if settings.playbackMode == .teacherMode {
                VStack(spacing: 10) {
                    Stepper("Pause Duration 暫停時間: \(settings.pauseDuration)s",
                            value: $settings.pauseDuration,
                            in: 1...15)
                    Stepper("Repetitions 重複次數: \(settings.repetitions)",
                            value: $settings.repetitions,
                            in: 1...5)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var speedSliderSection: some View {
        VStack(alignment: .leading) {
            Text("Speed 速度: \(String(format: "%.2f", settings.playbackSpeed))x")
            Slider(value: $settings.playbackSpeed,
                   in: 0.05...1.0,
                   step: 0.05)
        }
        .padding(.horizontal)
    }
    
    private var languagePickerSection: some View {
        Picker("Language 語言", selection: $settings.audioLanguage) {
            ForEach(AudioLanguage.allCases, id: \.self) { language in
                Text(language.rawValue).tag(language)
            }
        }
        .pickerStyle(.menu)
        .padding(.horizontal)
    }
    
    private var playbackControlsSection: some View {
        HStack(spacing: 10) {
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
                            text: settings.processTextForSpeech(playbackManager.sentences.joined(separator: " ")),
                            language: settings.audioLanguage,
                            rate: settings.playbackSpeed
                        )
                    case .sentenceBySentence:
                        playbackManager.currentSentenceIndex = 0
                        if let sentence = playbackManager.getCurrentSentence() {
                            playbackManager.isPlaying = true
                            ttsManager.speak(
                                text: settings.processTextForSpeech(sentence),
                                language: settings.audioLanguage,
                                rate: settings.playbackSpeed
                            )
                        }
                    case .teacherMode:
                        if subscriptionManager.isPremium {
                            playbackManager.currentSentenceIndex = 0
                            playbackManager.startTeacherMode(ttsManager: ttsManager, settings: settings)
                        } else {
                            showUpgradePrompt = true
                        }
                    }
                }
            }) {
                if settings.playbackMode == .sentenceBySentence {
                    Image(systemName: playbackManager.isPlaying ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                } else {
                    Label(playbackManager.isPlaying ? "Stop 停止" : "Play 播放",
                          systemImage: playbackManager.isPlaying ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .disabled(settings.sentences.isEmpty)
            
            // Restart Button (Whole Passage mode only)
            if settings.playbackMode == .wholePassage {
                Button(action: {
                    ttsManager.stopSpeaking()
                    playbackManager.isPlaying = true
                    ttsManager.speak(
                        text: settings.processTextForSpeech(playbackManager.sentences.joined(separator: " ")),
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
                    if subscriptionManager.isPremium {
                        playbackManager.currentSentenceIndex = 0
                        playbackManager.startTeacherMode(ttsManager: ttsManager, settings: settings)
                    } else {
                        showUpgradePrompt = true
                    }
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
                    playbackManager.currentSentenceIndex = 0
                    if let sentence = playbackManager.getCurrentSentence() {
                        playbackManager.isPlaying = true
                        ttsManager.speak(
                            text: settings.processTextForSpeech(sentence),
                            language: settings.audioLanguage,
                            rate: settings.playbackSpeed
                        )
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(settings.sentences.isEmpty)
                
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
                    Image(systemName: "backward.fill")
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
                    Image(systemName: "forward.fill")
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
    }
    
    private var progressTextSection: some View {
        Text(playbackManager.getProgressText())
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    private var voiceAvailabilityWarningSection: some View {
        Group {
            if !settings.isSelectedVoiceAvailable() {
                Text("Please download the \(settings.audioLanguage.rawValue) voice in Settings > Accessibility > Spoken Content > Voices 請在設置 > 輔助功能 > 語音內容 > 語音中下載\(settings.audioLanguage.rawValue)語音")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
    
    private var bannerAdSection: some View {
        Group {
            if isFreeUser {
                BannerAdView()
                    .frame(height: 50)
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
        .environmentObject(SubscriptionManager.shared)
}
