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

    @State private var turnOrder: [String] = []
    @State private var currentTurnIndex: Int = 0
    @State private var playerInputs: [Int: [String: String]] = [:]
    @State private var myWordInput: String = ""
    @State private var showGuessPopup = false

    private let deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString
    private var isHost: Bool { hostId == deviceId }
    private var iAmSpy: Bool { myRole == "spy" }

    struct PlayerRow: Identifiable {
        let id: String
        let name: String
        var role: String? = nil
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
                        endGameAndReset()
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
                        Text("round_progress \(currentRound) \(totalRounds)")
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

                            // STEP 2: After pressing continue → show player list and turn
                            if continuePressed {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("players")
                                        .font(.h2)

                                    if selectedPlayers.isEmpty {
                                        Text("no_players").foregroundColor(.secondary)
                                    } else {
                                        ForEach(selectedPlayers) { p in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(p.name).bold()
                                                ForEach(playerInputs.keys.sorted(), id: \.self) { roundNum in
                                                    if let word = playerInputs[roundNum]?[p.id] {
                                                        Text("Round \(roundNum): \(word)")
                                                            .font(.caption)
                                                            .foregroundColor(.primaryBlue)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.backgroundLight)
                                .cornerRadius(12)
                                .shadow(radius: 2)

                                // sıradaki oyuncu input
                                if turnOrder.indices.contains(currentTurnIndex),
                                   turnOrder[currentTurnIndex] == deviceId, status != "guessReady" {
                                    VStack(spacing: 12) {
                                        TextField("enter_word", text: $myWordInput)
                                            .textFieldStyle(.roundedBorder)
                                            .padding(.horizontal)

                                        ButtonText(title: "send_word") {
                                            submitWord()
                                        }
                                    }
                                    .padding()
                                }
                                
                                if status == "guessReady" {
                                    Button("Spy tahmin et") {
                                        showGuessPopup = true
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.primaryBlue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }

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
        .overlay {
            if showGuessPopup {
                SpyGuessView(
                    roomCode: roomCode,
                    players: selectedPlayers,
                    deviceId: deviceId,
                    isHost: isHost,
                    isPresented: $showGuessPopup,
                    router: router
                )
            }
        }
        .onAppear {
            attachListeners()
            if hasSeenRole() {
                revealedOnce = true
                continuePressed = true
            }
        }
        .onChange(of: status) { _, new in
            if !isGameStatus(new) && new != "guessing" && new != "guessReady" && new != "result" {
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

// MARK: - Extension
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

            self.currentRound = (info["currentRound"] as? Int) ?? 1
            self.totalRounds = (info["totalRounds"] as? Int) ?? 3
            self.turnOrder = (info["turnOrder"] as? [String]) ?? []

            self.isLoading = false
            self.currentTurnIndex = (info["currentTurnIndex"] as? Int) ?? 0
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

                if isSelected { picked.append(.init(id: id, name: name, role: role)) }
                if id == deviceId {
                    meSelected = isSelected
                    myRoleLocal = role
                }
            }

            self.selectedPlayers = picked.sorted { $0.name < $1.name }
            self.amSelected = meSelected
            self.myRole = myRoleLocal
        }

        // rounds listener
        roomRef.collection("rounds").addSnapshotListener { qs, _ in
            var updated = self.playerInputs
            qs?.documents.forEach { doc in
                if let dict = doc.data() as? [String: String],
                   doc.documentID.starts(with: "round"),
                   let roundNum = Int(doc.documentID.dropFirst(5)) {
                    updated[roundNum] = dict
                }
            }
            self.playerInputs = updated
        }
    }

    // MARK: - Host: end game and reset
    private func endGameAndReset() {
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)

        // info reset
        roomRef.updateData([
            "info.status": "waiting",
            "info.currentRound": 1,
            "info.currentTurnIndex": 0
        ]) { err in
            if let err = err {
                self.errorMessage = err.localizedDescription
            }
        }

        // rounds temizle
        roomRef.collection("rounds").getDocuments { qs, _ in
            qs?.documents.forEach { doc in
                doc.reference.delete()
            }
        }

        // guesses temizle
        roomRef.collection("guesses").getDocuments { qs, _ in
            qs?.documents.forEach { doc in
                doc.reference.delete()
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

    // MARK: - Submit word
    private func submitWord() {
        guard !myWordInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let db = Firestore.firestore()
        let roundRef = db.collection("rooms")
            .document(roomCode)
            .collection("rounds")
            .document("round\(currentRound)")

        roundRef.setData([
            deviceId: myWordInput
        ], merge: true)

        myWordInput = ""

        let roomRef = db.collection("rooms").document(roomCode)

        if currentTurnIndex + 1 < turnOrder.count {
            roomRef.updateData([
                "info.currentTurnIndex": currentTurnIndex + 1
            ])
        } else {
            if currentRound < totalRounds {
                roomRef.updateData([
                    "info.currentRound": currentRound + 1,
                    "info.currentTurnIndex": 0
                ])
            } else {
                roomRef.updateData([
                    "info.status": "guessReady"
                ])
            }
        }

        // ✅ Kendi turum bitti, inputu gizle
        currentTurnIndex = -1
    }

}

// MARK: - SpyGuessView
struct SpyGuessView: View {
    let roomCode: String
    let players: [GameDetailView.PlayerRow]
    let deviceId: String
    let isHost: Bool
    @Binding var isPresented: Bool
    var router: Router

    @State private var selectedId: String? = nil
    @State private var votes: [String: String] = [:] // deviceId → votedId
    @State private var resultText: String? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 16) {
                // ✅ Sayaç en üstte
                HStack {
                    Spacer()
                    Text("\(votes.count)/\(players.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .onChange(of: votes) { _, newVotes in
                    let db = Firestore.firestore()
                    db.collection("rooms").document(roomCode).addSnapshotListener { snap, _ in
                        if let data = snap?.data(),
                           let info = data["info"] as? [String: Any],
                           let result = info["resultText"] as? String {
                            self.resultText = result
                        }
                    }
                }

                if let result = resultText {
                    // SONUÇ
                    Text(result)
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.primaryBlue)
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(players) { p in
                            Text("\(p.name) - \(p.role ?? "?")")
                                .font(.body)
                        }
                    }
                    .padding()
                    .background(Color.backgroundLight)
                    .cornerRadius(12)

                    // ✅ sadece host'a bitir
                    if isHost {
                        Button("Bitir") {
                            isPresented = false
                            router.replace(with: RoomView(roomCode: roomCode))

                            let db = Firestore.firestore()
                            let roomRef = db.collection("rooms").document(roomCode)
                            roomRef.updateData([
                                "info.status": "waiting",
                                "info.currentRound": 1,
                                "info.currentTurnIndex": 0
                            ])

                            // rounds temizle
                            roomRef.collection("rounds").getDocuments { qs, _ in
                                qs?.documents.forEach { doc in
                                    doc.reference.delete()
                                }
                            }
                            // guesses temizle
                            roomRef.collection("guesses").getDocuments { qs, _ in
                                qs?.documents.forEach { doc in
                                    doc.reference.delete()
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.primaryBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                } else {
                    // OYLAMA
                    Text("Kim spy?")
                        .font(.title2).bold()
                    ForEach(players) { p in
                        Button {
                            selectedId = p.id
                        } label: {
                            HStack {
                                Text(p.name)
                                Spacer()
                                if votes.values.contains(p.id) {
                                    Text("\(votes.values.filter{$0==p.id}.count)")
                                        .padding(6)
                                        .background(Color.primaryBlue)
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                }
                            }
                            .padding()
                            .background(selectedId == p.id ? Color.secondaryBlue.opacity(0.3) : Color.backgroundLight)
                            .cornerRadius(8)
                        }
                        .disabled(votes[deviceId] != nil)
                    }

                    if votes[deviceId] == nil, let sel = selectedId {
                        Button("Oy ver") {
                            castVote(for: sel)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.primaryBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    if votes[deviceId] != nil, votes.count != players.count {
                        Text("Oyunu kullandın. Diğer oyuncular bekleniyor.")
                            .foregroundColor(.secondary)
                    }
                    
                    if votes.count == players.count {
                        Text("Tüm oylar kullanıldı, kurucu bekleniyor.")
                            .foregroundColor(.secondary)
                    }
                    
                    if isHost {
                        Button("Devam et") {
                            showResult()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.primaryBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 300)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
        }
        .onAppear {
            attachGuessListener()
        }
    }

    private func castVote(for targetId: String) {
        selectedId = targetId
        let db = Firestore.firestore()
        let ref = db.collection("rooms")
            .document(roomCode)
            .collection("guesses")
            .document(deviceId)

        ref.setData(["vote": targetId])
    }

    private func attachGuessListener() {
        let db = Firestore.firestore()
        let ref = db.collection("rooms").document(roomCode).collection("guesses")

        ref.addSnapshotListener { qs, _ in
            var dict: [String: String] = [:]
            qs?.documents.forEach { doc in
                if let v = doc.data()["vote"] as? String {
                    dict[doc.documentID] = v
                }
            }
            self.votes = dict
        }
        
        let roomRef = db.collection("rooms").document(roomCode)
        roomRef.addSnapshotListener { snap, _ in
            if let data = snap?.data(),
               let info = data["info"] as? [String: Any],
               let result = info["resultText"] as? String {
                self.resultText = result
            }
        }
    }

    private func showResult() {
        let tally = Dictionary(grouping: votes.values, by: { $0 }).mapValues { $0.count }
        if let maxId = tally.max(by: { $0.value < $1.value })?.key,
           let spy = players.first(where: { $0.role == "spy" }) {
            
            let votedPlayerName = players.first(where: { $0.id == maxId })?.name ?? "Bilinmiyor"
            
            if maxId == spy.id {
                resultText = "Doğru! Spy bulundu: \(spy.name)"
            } else {
                resultText = "Yanlış! En çok oyu alan: \(votedPlayerName). Gerçek spy: \(spy.name)"
            }
            
            let db = Firestore.firestore()
            let roomRef = db.collection("rooms").document(roomCode)
            let safeResult = resultText ?? ""
            roomRef.updateData([
                "info.status": "result",
                "info.resultText": safeResult
            ])
        } else {
            resultText = "Sonuç belirlenemedi."
            let db = Firestore.firestore()
            let roomRef = db.collection("rooms").document(roomCode)
            let safeResult = resultText ?? ""
            roomRef.updateData([
                "info.status": "result",
                "info.resultText": safeResult
            ])
        }
    }
}
