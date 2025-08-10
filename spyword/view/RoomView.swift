import SwiftUI
import FirebaseCore
import FirebaseFirestore

// MARK: - Player Model
struct Player: Identifiable, Equatable {
    let id: String      // deviceId
    let name: String
    let role: String?
    var isEliminated: Bool?
    var isSelected: Bool?
}

// MARK: - RoomView
struct RoomView: View {
    let roomCode: String
    
    @StateObject private var vm: RoomViewModel
    @EnvironmentObject var router: Router
    
    // for alert when removed
    @State private var showRemovedAlert = false

    // current device
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
                        // RoomView.swift (excerpt showing current-user indicator)
                        ForEach(vm.players) { p in
                            HStack {
                                Text(p.name)
                                    .font(.body)
                                    .foregroundColor(.black)

                                Spacer()

                                // Indicator for yourself
                                if p.id == deviceId {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.successGreen)
                                        .help("Sen buradasın")
                                }

                                // Remove button for host
                                if isHost && p.id != deviceId {
                                    Button("Kaldır") {
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
                            .padding(.horizontal)
                        }

                    }
                    .padding(.top)
                }
            }
            
            Spacer()
            
            // Start button
            if isHost {
                ButtonText(
                    title: "Oyunu Başlat",
                    action: {
                        router.navigate(
                            to: GameDetailView(roomCode: roomCode),
                            type: .push
                        )
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
        }
        .alert("Odadan Kaldırıldınız", isPresented: $showRemovedAlert) {
            Button("Ana Menü") {
                router.navigate(to: MainView().withRouter(), type: .modal)
            }
        } message: {
            Text("Host tarafından odadan çıkarıldınız.")
        }
    }
    
    private var isHost: Bool {
        vm.hostId == deviceId
    }
}
