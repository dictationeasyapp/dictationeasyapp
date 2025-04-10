import SwiftUI

enum TabSelection: String {
    case scan
    case text
    case speech
}

struct ContentView: View {
    @StateObject private var settings = SettingsModel()
    @StateObject private var ocrManager = OCRManager()
    @StateObject private var ttsManager = TTSManager()
    @StateObject private var playbackManager = PlaybackManager()
    @State private var selectedTab: TabSelection = .scan
    @State private var isEditingPastDictation: Bool = false
    @State private var isProgrammaticNavigation: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ScanTabView(
                selectedTab: $selectedTab,
                isEditingPastDictation: $isEditingPastDictation,
                onNavigateToText: { isProgrammatic in
                    isProgrammaticNavigation = isProgrammatic
                    selectedTab = .text
                }
            )
            .tabItem {
                Label("Scan 掃描", systemImage: "camera")
            }
            .tag(TabSelection.scan)
            .environmentObject(settings)
            .environmentObject(ocrManager)

            TextTabView(selectedTab: $selectedTab, isEditingPastDictation: isEditingPastDictation)
                .tabItem {
                    Label("Text 文字", systemImage: "doc.text")
                }
                .tag(TabSelection.text)
                .environmentObject(settings)
                .environmentObject(ocrManager)

            SpeechTabView()
                .tabItem {
                    Label("Speech 朗讀", systemImage: "speaker.wave.2")
                }
                .tag(TabSelection.speech)
                .environmentObject(settings)
                .environmentObject(ttsManager)
                .environmentObject(playbackManager)
        }
        .onChange(of: selectedTab) { newTab in
            #if DEBUG
            print("ContentView - selectedTab changed to: \(newTab.rawValue), isProgrammaticNavigation: \(isProgrammaticNavigation), isEditingPastDictation: \(isEditingPastDictation)")
            #endif
            
            if newTab == .text && !isProgrammaticNavigation {
                isEditingPastDictation = false
            }
            
            isProgrammaticNavigation = false
        }
    }
}

#Preview {
    ContentView()
}
