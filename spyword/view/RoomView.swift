import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct Player: Identifiable, Equatable {
    let id: String
    let name: String
    let role: String?
    var isEliminated: Bool?
    var isSelected: Bool?
}

struct RoomView: View {
    let roomCode: String

    @StateObject private var vm: RoomViewModel
    @EnvironmentObject var router: Router

    @State private var showRemovedAlert = false
    @State private var navigatedToGame = false

    private let deviceId = UserDefaults.standard.string(forKey: "deviceId")
        ?? UUID().uuidString

    init(roomCode: String) {
        self.roomCode = roomCode
        _vm = StateObject(wrappedValue: RoomViewModel(roomCode: roomCode))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                Button {
                    router.replace(with: MainView())
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                    }
                    .font(.body)
                }

                Divider().frame(height: 20)

                Text("Oda Kodu: \(roomCode)")
                    .font(.body)
                    .foregroundColor(.black)

                StatusBadge(status: vm.status)

                Spacer()

                Button {
                    UIPasteboard.general.string = roomCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondaryBlue)
                }
            }
            .padding()
            .background(Color.backgroundLight)
            .shadow(radius: 2)

            Divider()

            // Players list
            if vm.isLoading {
                ProgressView().padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.players) { p in
                            HStack {
                                Text(p.name)
                                    .font(.body)
                                    .foregroundColor(.black)
                                Spacer()
                                if p.id == deviceId {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.successGreen)
                                        .help("Sen buradasın")
                                }
                                if isHost && p.id != deviceId {
                                    Button("Kaldır") { vm.remove(player: p) }
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.errorRed)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
            }

            Spacer()

            if isHost {
                ButtonText(
                    title: "Oyunu Başlat",
                    action: {
                        vm.beginArranging()
                        router.replace(with: SelectPlayersView(roomCode: roomCode, vm: vm))
                    },
                    backgroundColor: vm.players.count >= 2 ? .primaryBlue : .gray,
                    textColor: .white,
                    cornerRadius: 12,
                    size: .big
                )
                .disabled(vm.players.count < 2)
                .padding()
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.errorRed)
                    .padding(.bottom)
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
        .alert("Odadan Kaldırıldınız", isPresented: $showRemovedAlert) {
            Button("Ana Menü") {
                router.replace(with: MainView())
            }
        } message: {
            Text("Host tarafından odadan çıkarıldınız.")
        }
    }

    // MARK: - Helpers
    private var isHost: Bool { vm.hostId == deviceId }
    private var amSelected: Bool { vm.players.first(where: { $0.id == deviceId })?.isSelected == true }

    private func isGameStatus(_ s: String) -> Bool {
        let l = s.lowercased()
        return l == "the game" || l == "started" || l == "in game"
    }

    private func checkAndNavigateToGame() {
        guard !navigatedToGame else { return }
        guard isGameStatus(vm.status) else { return }
        guard amSelected else { return }
        navigatedToGame = true
        router.replace(with: GameDetailView(roomCode: roomCode))
    }
}
