import SwiftUI

@main
struct DictationEasyApp: App {
    // Integrate AppDelegate for UIKit lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
