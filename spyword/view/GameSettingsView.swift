import SwiftUI

struct GameSettingsView: View {
    // MARK: - Inputs
    @ObservedObject var vm: RoomViewModel
    @EnvironmentObject var router: Router
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.colorScheme) var colorScheme

    let roomCode: String
    let selectedIds: [String]

    @State private var showStartSplash = false
    
    // MARK: - Device
    private let deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString

    // MARK: - Computed
    private var maxSpyCount: Int {
        max(1, selectedIds.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                Text("game_settings_title")
                    .font(.title3)
                    .bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                StatusBadge(status: "arranging")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)

            Divider()

            // Main form
            Form {
                Section(header: Text("word_section")) {
                    Picker(selection: $vm.mode) {
                        Text("word_mode_random").tag(GameSettings.WordMode.random)
                        Text("word_mode_custom").tag(GameSettings.WordMode.custom)
                    } label: {}
                    .pickerStyle(.inline)

                    if vm.mode == .custom {
                        TextField("enter_word", text: $vm.customWord)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .onChange(of: vm.customWord) { _, new in
                                if new.count > 40 { vm.customWord = String(new.prefix(40)) }
                            }

                        Text("custom_word_note")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("numeric_settings")) {
                    Stepper(value: $vm.spyCount, in: 0...maxSpyCount) {
                        HStack {
                            Text("spy_count")
                            Spacer()
                            Text("\(vm.spyCount)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $vm.totalRounds, in: 1...10) {
                        HStack {
                            Text("round_count")
                            Spacer()
                            Text("\(vm.totalRounds)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    vm.setStatus("waiting")
                    router.replace(with: RoomView(roomCode: roomCode))
                } label: {
                    Text("cancel")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.primaryBlue)
                        .cornerRadius(12)
                }

                Button(action: startGame) {
                    Text("start_game")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canStart ? Color.successGreen : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!canStart)
            }
            .padding()
        }
        .background(colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            enforceHostOnly()
            setDefaultSpyCount()
        }
        .slidingPage(
            isPresented: $showStartSplash,
            text: String.localized(key: "game_starts", code: lang.code)
        )
        .onChange(of: showStartSplash) { _, isShowing in
            if !isShowing {
                router.replace(with: GameDetailView(roomCode: roomCode))
            }
        }
    }
}

// MARK: - Helpers
extension GameSettingsView {
    private func startGame() {
        let settings = GameSettings(
            mode: vm.mode,
            customWord: vm.mode == .custom ? vm.customWord : nil,
            spyCount: vm.spyCount,
            totalRounds: vm.totalRounds
        )
        vm.startGame(selectedIds: selectedIds, settings: settings)
        showStartSplash = true
    }

    private func enforceHostOnly() {
        if vm.hostId != deviceId {
            router.pop()
        }
    }

    private func setDefaultSpyCount() {
        vm.spyCount = min(0, maxSpyCount)
    }

    private var canStart: Bool {
        guard selectedIds.count >= 2 else { return false }
        if vm.mode == .custom {
            return !vm.customWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }
}
