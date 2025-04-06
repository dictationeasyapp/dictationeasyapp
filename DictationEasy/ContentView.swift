import SwiftUI

enum TabSelection {
    case scan
    case text
    case speech
}

struct ContentView: View {
    @State private var selectedTab: TabSelection = .scan
    @StateObject private var settings = SettingsModel()
    @StateObject private var ocrManager = OCRManager()
    @StateObject private var ttsManager = TTSManager()
    @StateObject private var playbackManager = PlaybackManager()

    var body: some View {
        TabView(selection: $selectedTab) {
            ScanTabView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Scan 掃描", systemImage: "doc.text.viewfinder")
                }
                .tag(TabSelection.scan)

            TextTabView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Text 文字", systemImage: "text.alignleft")
                }
                .tag(TabSelection.text)

            SpeechTabView()
                .tabItem {
                    Label("Speech 朗讀", systemImage: "speaker.wave.2")
                }
                .tag(TabSelection.speech)
        }
        .environmentObject(settings)
        .environmentObject(ocrManager)
        .environmentObject(ttsManager)
        .environmentObject(playbackManager)
    }
}

#Preview {
    ContentView()
}
