import SwiftUI

private enum Constant {
    static let privacyPolicyUrl = URL(string: "https://infoappwide.github.io/spyWordPrivacyPolicy/")
    static let deviceIdKey = "deviceId"
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
                    .cornerRadius(8)
                
                Spacer()
                
                ButtonText(title: "Oyun Yarat") {
                    router.navigate(to: CreateRoomView().withRouter(), type: .push)
                }
                
                ButtonText(title: "Oyuna Katıl") {
                    router.navigate(to: JoinGameView().withRouter(), type: .push)
                }
                
                Spacer()
                
                ButtonIcon(iconName: "lock.shield") {
                    if let url = Constant.privacyPolicyUrl {
                        UIApplication.shared.open(url)
                    }
                }
                .padding(.bottom, 48)
            }
            .padding()
        }
        .onAppear(perform: setupDeviceIDIfNeeded)
    }

    /// Ensures a unique deviceId exists in UserDefaults for all game operations
    private func setupDeviceIDIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: Constant.deviceIdKey) == nil {
            let newId = UUID().uuidString
            defaults.set(newId, forKey: Constant.deviceIdKey)
            print("🔑 Generated new deviceId: \(newId)")
        } else {
            let existing = defaults.string(forKey: Constant.deviceIdKey)!
            print("🔐 Using existing deviceId: \(existing)")
        }
    }
}
