import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct RoomView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.colorScheme) var colorScheme

    let roomCode: String

    @StateObject private var vm: RoomViewModel

    @State private var showRemovedAlert = false
    @State private var navigatedToGame = false
    @State private var showCopiedToast = false
    @State private var showStartSplash = false

    private let deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString

    init(roomCode: String) {
        self.roomCode = roomCode
        _vm = StateObject(wrappedValue: RoomViewModel(roomCode: roomCode))
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .top) {
            (colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        router.replace(with: MainView())
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                        }
                        .font(.body)
                        .foregroundColor(.primary)
                    }

                    Divider().frame(height: 20)

                    Text(String.localized(key: "room_code", code: lang.code, roomCode))
                        .font(.body)
                        .foregroundColor(.primary)

                    Button {
                        UIPasteboard.general.string = roomCode
                        withAnimation(.spring) { showCopiedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.spring) { showCopiedToast = false }
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel(Text("copy"))
                    
                    Spacer()

                    StatusBadge(status: vm.status)
                }
                .padding()
                .background(colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
                .shadow(radius: 2)

                Divider()

                playersList()
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer(minLength: 0)

                if isHost {
                    let canStart = vm.players.count >= 2
                    ButtonText(
                        title: LocalizedStringKey("start_game"),
                        action: {
                            vm.beginArranging()
                            router.replace(with: SelectPlayersView(roomCode: roomCode, vm: vm))
                        },
                        backgroundColor: canStart ? .successGreen : .gray,
                        textColor: .white,
                        cornerRadius: 12,
                        size: .big
                    )
                    .disabled(!canStart)
                    .padding()
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.errorRed)
                        .padding(.bottom)
                }
            }
            .safeAreaPadding(.bottom)
        }
        .keyboardAdaptive()
        .slidingPage(
            isPresented: $showStartSplash,
            text: String.localized(key: "game_starts", code: lang.code)
        )
        .onChange(of: showStartSplash) { _, isShowing in
            if !isShowing {
                router.replace(with: GameDetailView(roomCode: roomCode))
            }
        }
        .onChange(of: vm.players) { _, players in
            if !players.contains(where: { $0.id == deviceId }) {
                showRemovedAlert = true
            }
            checkAndNavigateToGame()
        }
        .onChange(of: vm.status) { _, _ in
            checkAndNavigateToGame()
        }
        .onAppear { checkAndNavigateToGame() }
        .alert(LocalizedStringKey("removed_from_room_title"), isPresented: $showRemovedAlert) {
            Button(LocalizedStringKey("main_menu")) {
                router.replace(with: MainView())
            }
        } message: {
            Text("removed_from_room_message")
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("copied")
                        .font(.caption)
                        .bold()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.95))
                .foregroundColor(.primary)
                .cornerRadius(20)
                .shadow(radius: 6)
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func playersList() -> some View {
        if vm.isLoading {
            ProgressView()
                .padding()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.players) { p in
                        HStack(spacing: 12) {
                            Text(p.name)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            if p.id == deviceId {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.successGreen)
                                    .help(Text("you_are_here"))
                            }

                            if isHost && p.id != deviceId {
                                Button(LocalizedStringKey("remove")) {
                                    vm.remove(player: p)
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.errorRed)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - Helpers (Extension)
extension RoomView {
    private var isHost: Bool { vm.hostId == deviceId }
    private var amSelected: Bool { vm.players.first(where: { $0.id == deviceId })?.isSelected == true }

    private func isGameStatus(_ s: String) -> Bool {
        switch s.lowercased() {
        case "the game", "started", "in game", "guessready", "result":
            return true
        default:
            return false
        }
    }

    private func checkAndNavigateToGame() {
        guard !navigatedToGame else { return }
        guard amSelected else { return }

        let st = vm.status.lowercased()
        guard ["the game", "started", "in game", "guessready", "result"].contains(st) else { return }

        navigatedToGame = true

        if ["guessready", "result"].contains(st) {
            router.replace(with: GameDetailView(roomCode: roomCode))
        } else {
            showStartSplash = true
        }
    }
}
