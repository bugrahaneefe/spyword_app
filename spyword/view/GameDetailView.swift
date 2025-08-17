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
    @State private var gameWord: String? = nil

    // round info
    @State private var currentRound: Int = 1
    @State private var totalRounds: Int = 3

    // role reveal states
    @State private var revealedOnce = false
    @State private var showCountdown = false
    @State private var countdown = 3
    @State private var continuePressed = false

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
                    router.replace(with: MainView())
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("main_menu")
                    }
                    .font(.body)
                }

                Spacer()

                StatusBadge(status: status)

                if isHost && isGameStatus(status) {
                    Button {
                        endGame()
                    } label: {
                        Text("end_game")
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
                    VStack(spacing: 20) {
                        Text(String(format: NSLocalizedString("round_progress", comment: ""), currentRound, totalRounds))
                            .font(.h2)
                            .foregroundColor(.primaryBlue)

                        if !amSelected {
                            VStack(spacing: 8) {
                                Text("not_selected")
                                    .font(.body)
                                ButtonText(title: "back_to_room") {
                                    router.replace(with: RoomView(roomCode: roomCode))
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.backgroundLight)
                            .cornerRadius(12)
                            .shadow(radius: 2)

                        } else {
                            // STEP 1: Show role reveal box
                            if !continuePressed {
                                VStack(spacing: 12) {
                                    if !revealedOnce {
                                        if showCountdown {
                                            Text(String(format: NSLocalizedString("role_reveal_countdown", comment: ""), countdown))
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("tap_to_reveal")
                                                .font(.body)
                                            ButtonText(title: "show_role") {
                                                startCountdown()
                                            }
                                        }
                                    } else {
                                        Text(roleTitleText)
                                            .font(.title3).bold()
                                        if !iAmSpy {
                                            if let word = gameWord {
                                                Text(String(format: NSLocalizedString("game_word", comment: ""), word))
                                                    .font(.body)
                                                    .foregroundColor(.primaryBlue)
                                            }
                                        }
                                        ButtonText(title: "continue") {
                                            continuePressed = true
                                        }
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.backgroundLight)
                                .cornerRadius(12)
                                .shadow(radius: 2)
                            }

                            // STEP 2: After pressing continue → show player list
                            if continuePressed {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("players")
                                        .font(.h2)

                                    if selectedPlayers.isEmpty {
                                        Text("no_players").foregroundColor(.secondary)
                                    } else {
                                        ForEach(selectedPlayers) { p in
                                            HStack {
                                                Text(p.name)
                                                Spacer()
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
                    }
                    .padding()
                }
            }

            Image("spyword")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
                .cornerRadius(12)
                .opacity(0.8)
                .padding(.bottom, 8)
        }
        .onAppear {
            attachListeners()
            if hasSeenRole() {
                revealedOnce = true
                continuePressed = true
            }
        }
        .onChange(of: status) { _, new in
            if !isGameStatus(new) {
                markRoleAs(revealStatus: false)
                router.replace(with: RoomView(roomCode: roomCode))
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var roleTitleText: String {
        switch myRole {
        case "spy":     return NSLocalizedString("role_spy", comment: "")
        case "knower":  return NSLocalizedString("role_knower", comment: "")
        default:        return NSLocalizedString("role_pending", comment: "")
        }
    }
}

extension GameDetailView {

    private func startCountdown() {
        showCountdown = true
        countdown = 3
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 1 {
                countdown -= 1
            } else {
                timer.invalidate()
                showCountdown = false
                markRoleAs(revealStatus: true)
            }
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
            self.gameWord = info["word"] as? String

            // 🆕 round bilgisi Firestore'dan alınabilir (dummy varsayılanlar)
            self.currentRound = (info["currentRound"] as? Int) ?? 1
            self.totalRounds = (info["totalRounds"] as? Int) ?? 3

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
        }
        self.status = "waiting"
    }
    
    private func markRoleAs(revealStatus: Bool) {
        revealedOnce = revealStatus
        UserDefaults.standard.set(revealStatus, forKey: "roleRevealed-\(roomCode)-\(deviceId)")
    }
        
    private func hasSeenRole() -> Bool {
        return UserDefaults.standard.bool(forKey: "roleRevealed-\(roomCode)-\(deviceId)")
    }
}
