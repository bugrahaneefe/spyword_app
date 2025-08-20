import SwiftUI
import FirebaseFirestore

struct GameDetailView: View {
    let roomCode: String

    @EnvironmentObject var router: Router
    @Environment(\.colorScheme) var colorScheme

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

    private var cardBG: Color { colorScheme == .dark ? Color.black : Color.white }
    private var pageBG: Color { colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight }

    init(roomCode: String) {
        self.roomCode = roomCode

        let did = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString
        let seenKey = "roleRevealed-\(roomCode)-\(did)"
        let seen = UserDefaults.standard.bool(forKey: seenKey)
        
        _revealedOnce   = State(initialValue: seen)
        _continuePressed = State(initialValue: seen)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            pageBG.ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar()
                Divider()
                contentArea()
            }
            .safeAreaPadding(.bottom)
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
            if isResultPhase(status) && amSelected {
                showGuessPopup = true
            }
            if isGuessRelated(status) { continuePressed = true }
        }
        .onChange(of: status) { _, new in
            if isResultPhase(new) && amSelected {
                showGuessPopup = true
            } else if !isGuessRelated(new) {
                showGuessPopup = false
            }
            if isGuessRelated(new) { continuePressed = true }
            if !isGameStatus(new) && !isGuessRelated(new) {
                markRoleAs(revealStatus: false)
                router.replace(with: RoomView(roomCode: roomCode))
            }
        }
        .onChange(of: amSelected) { _, nowSelected in
            if nowSelected && isResultPhase(status) {
                showGuessPopup = true
            }
        }
        .onChange(of: status) { old, new in
            if new == "started", old != "started" {
                resetLocalForNewGame()

                if isHost {
                    let db = Firestore.firestore()
                    let roomRef = db.collection("rooms").document(roomCode)

                    roomRef.collection("rounds").getDocuments { qs, _ in
                        qs?.documents.forEach { $0.reference.delete() }
                    }
                    roomRef.collection("guesses").getDocuments { qs, _ in
                        qs?.documents.forEach { $0.reference.delete() }
                    }

                    roomRef.updateData([
                        "info.currentRound": 1,
                        "info.currentTurnIndex": 0,
                        "info.resultText": FieldValue.delete()
                    ])
                }
            }
            else if !isGameStatus(new) && new != "guessing" && new != "guessReady" && new != "result" {
                markRoleAs(revealStatus: false)
                router.replace(with: RoomView(roomCode: roomCode))
            }
        }

        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Subviews
extension GameDetailView {
    @ViewBuilder
    private func topBar() -> some View {
        HStack(spacing: 12) {
            Button {
                router.replace(with: MainView())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Room: \(roomCode)")
                }
                .font(.body)
                .foregroundColor(.primary)
            }
            .layoutPriority(2)

            Spacer(minLength: 8)

            StatusBadge(status: status)
                .layoutPriority(3)

            if isHost && isGameStatus(status) {
                Button(action: endGameAndReset) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.errorRed)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .frame(minWidth: 40, minHeight: 40)
                .layoutPriority(3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(pageBG)
        .shadow(radius: 2)
    }

    @ViewBuilder
    private func contentArea() -> some View {
        if isLoading {
            ProgressView().padding()
            Spacer()
        } else {
            VStack(spacing: 20) {
                headerRound()
                if !amSelected {
                    notSelectedCard()
                } else {
                    if shouldShowRoleReveal {
                        roleRevealCard()
                    }
                    if continuePressed {
                        playersInputsCard()
                        myTurnInputCard()
                        guessCTA()
                        if let e = errorMessage {
                            Text(e)
                                .font(.caption)
                                .foregroundColor(.errorRed)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding()
            .scrollDismissesKeyboard(.interactively)
            .keyboardAdaptive()
        }
    }

    @ViewBuilder
    private func headerRound() -> some View {
        Text("Round \(currentRound) / \(totalRounds)")
            .font(.h2)
            .foregroundColor(.primary)
    }

    @ViewBuilder
    private func notSelectedCard() -> some View {
        VStack(spacing: 8) {
            Text("You’re not selected for this game.")
                .font(.body)
                .foregroundColor(.secondary)

            ButtonText(title: "Back to room") {
                router.replace(with: RoomView(roomCode: roomCode))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(cardBG)
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    @ViewBuilder
    private func roleRevealCard() -> some View {
        VStack(spacing: 12) {
            if !revealedOnce {
                if showCountdown {
                    Text("Revealing in \(countdown)…")
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text("Tap to reveal your role")
                        .font(.body)
                    ButtonText(title: "Show Role") {
                        startCountdown()
                    }
                }
            } else {
                Text(roleTitleText)
                    .font(.title3).bold()
                    .foregroundColor(.primary)

                if !iAmSpy, let word = gameWord {
                    Text("Word: \(word)")
                        .font(.body)
                        .foregroundColor(.primaryBlue)
                }

                ButtonText(title: "Continue") {
                    continuePressed = true
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(cardBG)
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    @ViewBuilder
    private func playersInputsCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Players")
                .font(.h2)
                .foregroundColor(.primary)

            if selectedPlayers.isEmpty {
                Text("No players yet.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    ForEach(selectedPlayers) { p in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.name).bold().foregroundColor(.primary)
                            ForEach(playerInputs.keys.sorted(), id: \.self) { roundNum in
                                if let word = playerInputs[roundNum]?[p.id] {
                                    Text("Round \(roundNum): \(word)")
                                        .font(.caption)
                                        .foregroundColor(.primaryBlue)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .background(cardBG)
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    @ViewBuilder
    private func myTurnInputCard() -> some View {
        if turnOrder.indices.contains(currentTurnIndex),
           turnOrder[currentTurnIndex] == deviceId,
           status != "guessReady" {
            VStack(spacing: 12) {
                Spacer(minLength: 16)

                TextField("Enter a word…", text: $myWordInput)
                    .font(.body)
                    .padding()
                    .background(cardBG)
                    .cornerRadius(8)
                    .foregroundColor(.primary)
                    .shadow(color: .black.opacity(0.05), radius: 4)
                    .clearButton($myWordInput)

                ButtonText(title: "Send Word") {
                    submitWord()
                }
            }
            .padding()
            .background(cardBG.opacity(0))
        }
    }

    @ViewBuilder
    private func guessCTA() -> some View {
        if status == "guessReady" {
            Spacer(minLength: 16)
            
            ButtonText(
                title: "Guess the Spy",
                action: { showGuessPopup = true },
                backgroundColor: .primaryBlue,
                textColor: .white,
                cornerRadius: 12,
                size: .big
            )
            .padding(.horizontal)
        }
    }

    private var roleTitleText: String {
        switch myRole {
        case "spy":     return "Spy"
        case "knower":  return "Knower"
        default:        return "Pending role…"
        }
    }
}

// MARK: - Logic & Firestore
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
    
    private func isResultPhase(_ s: String) -> Bool {
        s.lowercased() == "result"
    }

    private func isGuessRelated(_ s: String) -> Bool {
        let l = s.lowercased()
        return l == "guessready" || l == "guessing" || l == "result"
    }
    
    private var shouldShowRoleReveal: Bool {
        // rol kartı sadece oyun aşamasında ve tahmin fazında DEĞİLSE gösterilir
        return !continuePressed && isGameStatus(status) && !isGuessRelated(status)
    }

    private func attachListeners() {
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)

        // info/status
        roomRef.addSnapshotListener { snap, _ in
            guard let data = snap?.data(),
                  let info = data["info"] as? [String: Any] else {
                self.errorMessage = "Room info couldn’t be read."
                self.isLoading = false
                return
            }
            self.status = (info["status"] as? String) ?? "started"
            self.hostId = (info["hostId"] as? String) ?? ""
            self.gameWord = info["word"] as? String

            self.currentRound = (info["currentRound"] as? Int) ?? 1
            self.totalRounds = (info["totalRounds"] as? Int) ?? 3
            self.turnOrder = (info["turnOrder"] as? [String]) ?? []
            self.currentTurnIndex = (info["currentTurnIndex"] as? Int) ?? 0

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

    private func endGameAndReset() {
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)

        roomRef.updateData([
            "info.status": "waiting",
            "info.currentRound": 1,
            "info.currentTurnIndex": 0,
            "info.resultText": FieldValue.delete()
        ]) { err in
            if let err = err {
                self.errorMessage = err.localizedDescription
            }
        }

        // clear rounds
        roomRef.collection("rounds").getDocuments { qs, _ in
            qs?.documents.forEach { doc in doc.reference.delete() }
        }

        // clear guesses
        roomRef.collection("guesses").getDocuments { qs, _ in
            qs?.documents.forEach { doc in doc.reference.delete() }
        }

        self.status = "waiting"
    }

    private func markRoleAs(revealStatus: Bool) {
        revealedOnce = revealStatus
        UserDefaults.standard.set(revealStatus, forKey: "roleRevealed-\(roomCode)-\(deviceId)")
    }

    private func hasSeenRole() -> Bool {
        UserDefaults.standard.bool(forKey: "roleRevealed-\(roomCode)-\(deviceId)")
    }

    private func submitWord() {
        guard !myWordInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let db = Firestore.firestore()
        let roundRef = db.collection("rooms")
            .document(roomCode)
            .collection("rounds")
            .document("round\(currentRound)")

        roundRef.setData([deviceId: myWordInput], merge: true)
        myWordInput = ""

        let roomRef = db.collection("rooms").document(roomCode)

        if currentTurnIndex + 1 < turnOrder.count {
            roomRef.updateData(["info.currentTurnIndex": currentTurnIndex + 1])
        } else {
            if currentRound < totalRounds {
                roomRef.updateData([
                    "info.currentRound": currentRound + 1,
                    "info.currentTurnIndex": 0
                ])
            } else {
                roomRef.updateData(["info.status": "guessReady"])
            }
        }

        // hide my input after turn ends
        currentTurnIndex = -1
    }
    
    private func resetLocalForNewGame() {
        // local UI state
        isLoading = false
        errorMessage = nil

        revealedOnce = false
        showCountdown = false
        countdown = 3
        continuePressed = false
        showGuessPopup = false

        myWordInput = ""
        playerInputs = [:]

        // tur/sayaç
        currentRound = 1
        currentTurnIndex = 0

        // içerik
        gameWord = nil

        // role reveal flag’i sıfırla (aynı odada yeni oyunda tekrar gösterilsin)
        markRoleAs(revealStatus: false)
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

    @State private var roomStatus: String = ""
    @State private var selectedId: String? = nil
    @State private var votes: [String: String] = [:]
    @State private var resultText: String? = nil
    @Environment(\.colorScheme) var colorScheme

    private var cardBG: Color { colorScheme == .dark ? Color.black : Color.white }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 16) {
                // counter
                HStack {
                    Spacer()
                    Text("\(votes.count)/\(players.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if roomStatus == "result", let result = resultText {
                    // RESULT
                    Text(result)
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.primaryBlue)
                        .cornerRadius(12)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(players) { p in
                            Text("\(p.name) - \(p.role ?? "?")")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(cardBG)
                    .cornerRadius(12)

                    if isHost {
                        ButtonText(title: "Finish Game") {
                            isPresented = false
                            router.replace(with: RoomView(roomCode: roomCode))

                            let db = Firestore.firestore()
                            let roomRef = db.collection("rooms").document(roomCode)
                            roomRef.updateData([
                                "info.status": "waiting",
                                "info.currentRound": 1,
                                "info.currentTurnIndex": 0
                            ])

                            roomRef.collection("rounds").getDocuments { qs, _ in
                                qs?.documents.forEach { $0.reference.delete() }
                            }
                            roomRef.collection("guesses").getDocuments { qs, _ in
                                qs?.documents.forEach { $0.reference.delete() }
                            }
                        }
                        .padding(.top, 4)
                    }

                } else {
                    // VOTING
                    Text("Who is the spy?")
                        .font(.title2).bold()
                        .foregroundColor(.primary)

                    ForEach(players) { p in
                        Button {
                            selectedId = p.id
                        } label: {
                            HStack {
                                Text(p.name).foregroundColor(.primary)
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
                            .background(selectedId == p.id ? Color.secondaryBlue.opacity(0.8) : Color.secondaryBlue.opacity(0.15))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(votes[deviceId] != nil)
                    }

                    if votes[deviceId] == nil, let sel = selectedId {
                        ButtonText(title: "Vote") {
                            castVote(for: sel)
                        }
                    }

                    if votes[deviceId] != nil, votes.count != players.count {
                        Text("You’ve voted. Waiting for others…")
                            .foregroundColor(.secondary)
                    }

                    if votes.count == players.count {
                        Text("All votes are in. Waiting for host…")
                            .foregroundColor(.secondary)
                    }

                    if isHost {
                        ButtonText(title: "Finish Voting") {
                            showResult()
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 320)
            .background(cardBG)
            .cornerRadius(16)
            .shadow(radius: 12)
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
               let info = data["info"] as? [String: Any] {

                self.roomStatus = (info["status"] as? String) ?? ""
                let newResult = info["resultText"] as? String

                self.resultText = (self.roomStatus == "result") ? newResult : nil
            }
        }
    }

    private func showResult() {
        let tally = Dictionary(grouping: votes.values, by: { $0 }).mapValues { $0.count }
        if let maxId = tally.max(by: { $0.value < $1.value })?.key,
           let spy = players.first(where: { $0.role == "spy" }) {

            let votedPlayerName = players.first(where: { $0.id == maxId })?.name ?? "Unknown"

            if maxId == spy.id {
                resultText = "Correct! Spy is found."
            } else {
                resultText = "Wrong! Spy has escaped."
            }

            let db = Firestore.firestore()
            let roomRef = db.collection("rooms").document(roomCode)
            roomRef.updateData([
                "info.status": "result",
                "info.resultText": resultText ?? ""
            ])
        } else {
            resultText = "No clear result."
            let db = Firestore.firestore()
            let roomRef = db.collection("rooms").document(roomCode)
            roomRef.updateData([
                "info.status": "result",
                "info.resultText": resultText ?? ""
            ])
        }
    }
}
