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
    @State private var showHowToSheet = false   // NEW

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

            // top-right: language + help (question mark) buttons
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Spacer()
                    ButtonIcon(iconName: "globe") {
                        showLanguageSheet = true
                    }
                    .padding(.trailing, 16)
                }

                HStack {
                    Spacer()
                    ButtonIcon(iconName: "questionmark.circle") {   // NEW
                        showHowToSheet = true
                    }
                    .padding(.trailing, 16)
                }

                Spacer()
            }
            .padding(.top, 16)
        }
        .onAppear(perform: setupDeviceIDIfNeeded)

        // Language sheet
        .sheet(isPresented: $showLanguageSheet) {
            LanguagePickerSheet(selected: lang.code) { newCode in
                lang.set(newCode)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }

        // How to play sheet
        .sheet(isPresented: $showHowToSheet) {
            HowToPlaySheet()       // NEW
                .environment(\.locale, lang.locale)
                .presentationDetents([.medium, .large])
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

// NEW: How-to sheet
private struct HowToPlaySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("how_intro")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Group {
                        Text("how_step_1").font(.body)
                        Text("how_step_2").font(.body)
                        Text("how_step_3").font(.body)
                        Text("how_step_4").font(.body)
                        Text("how_step_5").font(.body)
                        Text("how_step_6").font(.body)
                        Text("how_step_7").font(.body)
                        Text("how_step_8").font(.body)
                        Text("how_tips").font(.footnote).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            }
            .navigationTitle(Text("how_to_play_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
