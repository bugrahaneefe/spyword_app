import SwiftUI
import FirebaseFirestore

struct GameDetailView: View {
    let roomCode: String

    @EnvironmentObject var router: Router

    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var status: String = "started"
    @State private var selectedPlayers: [PlayerRow] = []

    @State private var hostId: String = ""
    @State private var amSelected = false
    @State private var myRole: String? = nil

    @State private var showRoleSheet = false
    @State private var revealedOnce = false

    private let deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString
    private var isHost: Bool { hostId == deviceId }
    private var iAmSpy: Bool { myRole == "spy" }

    struct PlayerRow: Identifiable {
        let id: String
        let name: String
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                Button {
                    router.replace(with: RoomView(roomCode: roomCode))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Odaya Dön")
                    }
                    .font(.body)
                }

                Spacer()

                StatusBadge(status: status)

                if isHost && isGameStatus(status) {
                    Button {
                        endGame()
                    } label: {
                        Text("Bitir")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.errorRed)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.backgroundLight)
            .shadow(radius: 2)

            Divider()

            if isLoading {
                ProgressView().padding()
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("🎮 Oyun Ekranı")
                            .font(.h2)
                            .foregroundColor(.primaryBlue)

                        if !amSelected {
                            // Not chosen → block with a friendly note
                            VStack(spacing: 8) {
                                Text("Bu oyun için seçilmediniz.")
                                    .font(.body)
                                ButtonText(title: "Odaya Dön") {
                                    router.replace(with: RoomView(roomCode: roomCode))
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.backgroundLight)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                        } else {
                            // Show / close "my role"
                            VStack(spacing: 10) {
                                Text(revealedOnce ? roleTitleText : "Rolünü görmek için bas:")
                                ButtonText(title: revealedOnce ? "Rolümü Tekrar Gör" : "Rolümü Göster") {
                                    revealedOnce = true
                                    showRoleSheet = true
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.backgroundLight)
                            .cornerRadius(12)
                            .shadow(radius: 2)

                            // Selected players list (names only for now)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Oyuncular")
                                    .font(.h2)

                                if selectedPlayers.isEmpty {
                                    Text("Oyuncu yok").foregroundColor(.secondary)
                                } else {
                                    ForEach(selectedPlayers) { p in
                                        HStack {
                                            Text(p.name)
                                            Spacer()
                                            // ileride ipucu burada görünecek
                                            Text("—").foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.backgroundLight)
                            .cornerRadius(12)
                            .shadow(radius: 2)

                            if let e = errorMessage {
                                Text(e)
                                    .font(.caption)
                                    .foregroundColor(.errorRed)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear(perform: attachListeners)
        .onChange(of: status) { _, new in
            // If host ended (or status changed), return users to RoomView
            if !isGameStatus(new) {
                router.replace(with: RoomView(roomCode: roomCode))
            }
        }
        .sheet(isPresented: $showRoleSheet) {
            RoleSheet(isSpy: iAmSpy, roleText: roleTitleText)
                .presentationDetents([.fraction(0.35), .medium])
                .presentationDragIndicator(.visible)
        }
        .navigationBarBackButtonHidden(true)
    }

    private var roleTitleText: String {
        switch myRole {
        case "spy":     return "Rolün: SPY 🕵️‍♂️"
        case "knower":  return "Rolün: Bilen ✅"
        default:        return "Rolün belirleniyor…"
        }
    }

    private func isGameStatus(_ s: String) -> Bool {
        let l = s.lowercased()
        return l == "the game" || l == "started" || l == "in game"
    }

    // MARK: - Firestore listeners
    private func attachListeners() {
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)

        // info/status
        roomRef.addSnapshotListener { snap, _ in
            guard let data = snap?.data(),
                  let info = data["info"] as? [String: Any] else {
                self.errorMessage = "Oda bilgisi okunamadı."
                self.isLoading = false
                return
            }
            self.status = (info["status"] as? String) ?? "started"
            self.hostId = (info["hostId"] as? String) ?? ""
            self.isLoading = false
        }

        // players
        roomRef.collection("players").addSnapshotListener { qs, _ in
            var picked: [PlayerRow] = []
            var meSelected = false
            var myRoleLocal: String? = nil

            qs?.documents.forEach { doc in
                let d = doc.data()
                let id = doc.documentID
                let name = (d["name"] as? String) ?? id
                let isSelected = (d["isSelected"] as? Bool) ?? false
                let role = d["role"] as? String

                if isSelected { picked.append(.init(id: id, name: name)) }
                if id == deviceId {
                    meSelected = isSelected
                    myRoleLocal = role
                }
            }

            self.selectedPlayers = picked.sorted { $0.name < $1.name }
            self.amSelected = meSelected
            self.myRole = myRoleLocal
        }
    }

    // MARK: - Host: end game
    private func endGame() {
        let roomRef = Firestore.firestore().collection("rooms").document(roomCode)
        roomRef.updateData([
            "info.status": "waiting"
        ]) { err in
            if let err = err {
                self.errorMessage = err.localizedDescription
            }
            // Everyone will observe status change and return to RoomView (onChange above)
        }
        
        self.status = "waiting"
    }
}

// MARK: - Bottom sheet for role
private struct RoleSheet: View {
    let isSpy: Bool
    let roleText: String

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 3)
                .frame(width: 40, height: 5)
                .foregroundColor(.secondary.opacity(0.4))
                .padding(.top, 8)

            Text(roleText)
                .font(.title2).bold()

            Text(isSpy ? "Kelime gösterilmeyecek." : "Kelimeyi bilen taraftasın.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }
}
