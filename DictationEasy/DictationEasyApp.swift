import SwiftUI
import RevenueCat

@main
struct DictationEasyApp: App {
    @StateObject private var settings = SettingsModel()
    @StateObject private var ocrManager = OCRManager()
    @StateObject private var ttsManager = TTSManager()
    @StateObject private var playbackManager = PlaybackManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        // Configure RevenueCat with your API key
        RevenueCat.Purchases.configure(withAPIKey: "appl_JrvqFvcSqXNUHBASFBSctYGKygR")
        RevenueCat.Purchases.shared.delegate = PurchasesDelegateHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(ocrManager)
                .environmentObject(ttsManager)
                .environmentObject(playbackManager)
                .environmentObject(subscriptionManager)
        }
    }
}

// Singleton to handle RevenueCat delegate methods
@MainActor
class PurchasesDelegateHandler: NSObject, RevenueCat.PurchasesDelegate, Sendable {
    static let shared = PurchasesDelegateHandler()

    private override init() {
        super.init()
    }

    nonisolated func purchases(_ purchases: RevenueCat.Purchases, receivedUpdated customerInfo: RevenueCat.CustomerInfo) {
        // Dispatch to the main actor since this method may be called on a background thread
        Task { @MainActor in
            NotificationCenter.default.post(name: .subscriptionStatusDidChange, object: nil)
        }
    }
}

// Notification name for subscription status changes
extension Notification.Name {
    static let subscriptionStatusDidChange = Notification.Name("subscriptionStatusDidChange")
}
