import SwiftUI

@main
struct spywordApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .withRouter()
        }
    }
}
