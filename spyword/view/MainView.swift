import SwiftUI

private enum Constant {
    static let privacyPolicyUrl = URL(string: "https://infoappwide.github.io/spyWordPrivacyPolicy/")
    static let deviceIdKey = "deviceId"
    static let appImage = Image("spyword")
}

struct MainView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var avatar: AvatarManager
    @Environment(\.colorScheme) var colorScheme

    @State private var showLanguageSheet = false
    @State private var showHowToSheet = false
    @State private var showAvatarSheet = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
                .ignoresSafeArea()

            // Centered content
            VStack(spacing: 24) {
                Spacer()
                Constant.appImage
                    .resizable()
                    .frame(width: 144, height: 144)
                    .cornerRadius(8)

                ButtonText(title: "create_game") { router.replace(with: CreateRoomView()) }
                ButtonText(title: "join_game")   { router.replace(with: JoinGameView()) }

                Spacer()
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            MainMenuBottomBar(
                onLanguage: { showLanguageSheet = true },
                onHowTo:    { showHowToSheet = true },
                onPrivacy:  {
                    if let url = Constant.privacyPolicyUrl { UIApplication.shared.open(url) }
                },
                onAvatar:   { showAvatarSheet = true }
            )
        }
        .onAppear(perform: setupDeviceIDIfNeeded)

        // Sheets
        .sheet(isPresented: $showLanguageSheet) {
            LanguagePickerSheet(selected: lang.code) { lang.set($0) }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHowToSheet) {
            HowToPlaySheet()
                .environment(\.locale, lang.locale)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAvatarSheet) {
            AvatarPickerSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func setupDeviceIDIfNeeded() {
        let k = Constant.deviceIdKey
        if UserDefaults.standard.string(forKey: k) == nil {
            UserDefaults.standard.set(UUID().uuidString, forKey: k)
        }
    }
}
