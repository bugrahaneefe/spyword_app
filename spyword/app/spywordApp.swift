import SwiftUI
import AppTrackingTransparency
import AdSupport

@main
struct SpyWordApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootContainer()
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        requestTrackingPermission()
                    }
                }
        }
    }
    
    @MainActor
    private func requestTrackingPermission() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:   print("✅ ATT: Authorized")
                case .denied:       print("❌ ATT: Denied")
                case .notDetermined:print("ℹ️ ATT: Not determined")
                case .restricted:   print("⚠️ ATT: Restricted")
                @unknown default:   break
                }
                
                AdsManager.shared.start()
            }
        } else {
            AdsManager.shared.start()
        }
    }
}
