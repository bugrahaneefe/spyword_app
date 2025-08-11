import SwiftUI

private enum Constant {
    static let privacyPolicyUrl = URL(string: "https://infoappwide.github.io/spyWordPrivacyPolicy/")
    static let deviceIdKey = "deviceId"
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
                
                Image("spyword")
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
                    Button {
                        showLanguageSheet = true
                    } label: {
                        Image(systemName: "globe")
                            .font(.title3)
                            .padding(10)
                            .background(Color.backgroundLight)
                            .clipShape(Circle())
                            .shadow(radius: 1)
                            .accessibilityLabel(Text("change_language")) // localized
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

struct LanguagePickerSheet: View {
    let selected: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 8) {
                    LanguageRow(
                        code: "tr",
                        title: String(localized: "language_turkish"),
                        selected: selected == "tr"
                    ) { onSelect("tr"); dismiss() }

                    LanguageRow(
                        code: "en",
                        title: String(localized: "language_english"),
                        selected: selected == "en"
                    ) { onSelect("en"); dismiss() }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle(Text("language_title"))
        }
    }
}

private struct LanguageRow: View {
    let code: String
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.primaryBlue)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                }
            }
            .padding()
            .background(Color.backgroundLight)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}
