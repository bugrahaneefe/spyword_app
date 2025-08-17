import SwiftUI

private enum Constant {
    static let privacyPolicyUrl = URL(string: "https://infoappwide.github.io/spyWordPrivacyPolicy/")
    static let deviceIdKey = "deviceId"
    static let appImage = Image("spyword")
}

struct MainView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.colorScheme) var colorScheme

    @State private var showLanguageSheet = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
                .ignoresSafeArea()

            // centered content
            VStack(spacing: 24) {
                
                Spacer()
                
                Constant.appImage
                    .resizable()
                    .frame(width: 144, height: 144)
                    .cornerRadius(8)

                ButtonText(title: "create_game") {
                    router.replace(with: CreateRoomView())
                }

                ButtonText(title: "join_game") {
                    router.replace(with: JoinGameView())
                }
                
                Spacer()
                
                ButtonIcon(iconName: "lock.shield") {
                    if let url = Constant.privacyPolicyUrl { UIApplication.shared.open(url) }
                }
                .padding(.top, 8)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // top-right language button
            VStack {
                HStack {
                    Spacer()
                    ButtonIcon(iconName: "globe") {
                        showLanguageSheet = true
                    }
                    .padding(.trailing, 16)
                }
                Spacer()
            }
            .padding(.top, 16)
        }
        .onAppear(perform: setupDeviceIDIfNeeded)
        .sheet(isPresented: $showLanguageSheet) {
            LanguagePickerSheet(selected: lang.code) { newCode in
                lang.set(newCode)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func setupDeviceIDIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: Constant.deviceIdKey) == nil {
            defaults.set(UUID().uuidString, forKey: Constant.deviceIdKey)
        }
    }
}

private struct LanguagePickerSheet: View {
    let selected: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 8) {
                    ButtonText(title: "language_turkish") {
                        onSelect("tr")
                        dismiss()
                    }
                    
                    ButtonText(title: "language_english") {
                        onSelect("en")
                        dismiss()
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(Text("language_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
