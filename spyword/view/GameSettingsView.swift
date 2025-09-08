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
                    
                    if vm.mode == .random {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                CategoryChip(titleKey: "category_world",    isSelected: vm.category == .world)        { vm.category = .world }
                                CategoryChip(titleKey: "category_turkiye",  isSelected: vm.category == .turkiye)      { vm.category = .turkiye }
                                CategoryChip(titleKey: "category_world_football", isSelected: vm.category == .worldFootball) { vm.category = .worldFootball }
                                CategoryChip(titleKey: "category_nfl",      isSelected: vm.category == .nfl)           { vm.category = .nfl }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Text("category_hint")
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
            totalRounds: vm.totalRounds,
            category: vm.category
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
        vm.spyCount = min(1, maxSpyCount)
    }

    private var canStart: Bool {
        guard selectedIds.count >= 2 else { return false }
        if vm.mode == .custom {
            return !vm.customWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }
}

private struct CategoryChip: View {
    let titleKey: LocalizedStringKey
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            onTap()
        } label: {
            Text(titleKey)
                .font(.caption).bold()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.primaryBlue.opacity(0.9) : (colorScheme == .dark ? Color.black.opacity(0.2) : Color.white))
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(isSelected ? Color.primaryBlue : Color.primary.opacity(0.15), lineWidth: 1)
                )
                .cornerRadius(999)
                .shadow(color: .black.opacity(isSelected ? 0.2 : 0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
