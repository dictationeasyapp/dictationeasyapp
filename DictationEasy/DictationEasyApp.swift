import SwiftUI
import GoogleMobileAds

@main
struct DictationEasyApp: App {
    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SettingsModel())
                .environmentObject(OCRManager())
                .environmentObject(TTSManager())
                .environmentObject(PlaybackManager())
        }
    }
}
