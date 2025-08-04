import SwiftUI

private enum Constant {
    static let privacyPolicyUrl = URL(string: "https://infoappwide.github.io/spyWordPrivacyPolicy/")
}

struct MainView: View {
    @EnvironmentObject var router: Router
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Image("spyword")
                    .resizable()
                    .frame(width: 144, height: 144)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                Spacer()
                
                ButtonText(title: "Oyun Yarat") {
                    router.navigate(to: SplashScreen(), type: .push)
                }
                
                
                ButtonText(title: "Oyuna Katıl") {
                    router.navigate(to: SplashScreen(), type: .push)
                }
                
                Spacer()
                
                VStack {
                    ButtonIcon(iconName: "lock.shield") {
                        if let url = Constant.privacyPolicyUrl {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .padding(.bottom, 48)
            }
            .padding()
        }
//        .task {
//            await setupDeviceIDIfNeeded()
//        }
    }

//    // 🔐 Save or retrieve unique device ID
//    func setupDeviceIDIfNeeded() async {
//        let key = "deviceId"
//        let defaults = UserDefaults.standard
//        if defaults.string(forKey: key) == nil {
//            let newId = UUID().uuidString
//            defaults.set(newId, forKey: key)
//            print("🔑 New deviceId created: \(newId)")
//        } else {
//            print("🔐 Existing deviceId: \(defaults.string(forKey: key) ?? "unknown")")
//        }
//    }
}
