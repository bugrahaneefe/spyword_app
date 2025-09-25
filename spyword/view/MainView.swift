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

            // centered content (unchanged)
            VStack(spacing: 24) {
                Spacer()
                Constant.appImage
                    .resizable()
                    .frame(width: 144, height: 144)
                    .cornerRadius(8)

                ButtonText(title: "create_game") { router.replace(with: CreateRoomView()) }
                ButtonText(title: "join_game")   { router.replace(with: JoinGameView()) }

                Spacer()

                ButtonIcon(iconName: "lock.shield") {
                    if let url = Constant.privacyPolicyUrl { UIApplication.shared.open(url) }
                }
                .padding(.top, 8)
            }
            .padding()

            VStack {
                HStack {
                    Button {
                        showAvatarSheet = true
                    } label: {
                        avatar.image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                            .shadow(radius: 2)
                            .accessibilityLabel(Text("Edit avatar"))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)

                    Spacer()
                }
                .padding(.top, 16)
                .shadow(color: .black, radius: 8)

                Spacer()
            }
            .padding(16)

            // TOP-RIGHT: language + help (unchanged)
            VStack(alignment: .trailing, spacing: 8) {
                HStack { Spacer()
                    ButtonIcon(iconName: "globe") { showLanguageSheet = true }
                        .padding(.trailing, 16)
                }
                HStack { Spacer()
                    ButtonIcon(iconName: "questionmark.circle") { showHowToSheet = true }
                        .padding(.trailing, 16)
                }
                Spacer()
            }
            .padding(.top, 16)
        }
        .onAppear(perform: setupDeviceIDIfNeeded)
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
        let k = "deviceId"
        if UserDefaults.standard.string(forKey: k) == nil {
            UserDefaults.standard.set(UUID().uuidString, forKey: k)
        }
    }
}
