import SwiftUI
import FirebaseFirestore

struct GameDetailView: View {
    let roomCode: String

    @EnvironmentObject var router: Router
    @EnvironmentObject var lang: LanguageManager
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
    @FocusState private var isWordFieldFocused: Bool
    @State private var showGuessPopup = false
    @State private var spyCount: Int = 1
    
    @State private var showTurnSplash = false
    @State private var lastSplashKey: String? = nil
    
    @State private var categoryRaw: String? = nil

    @State private var gameId: String = ""

    @State private var showEndGameConfirm = false
    @State private var isGuessTime = false
    
    private var categoryTitleKey: LocalizedStringKey? {
        if let raw = categoryRaw {
            switch raw {
            case "world":         return "category_world"
            case "turkiye":       return "category_turkiye"
            case "worldFootball": return "category_world_football"
            case "nfl":           return "category_nfl"
            case "movies":           return "category_movies"
            case "science":           return "category_science"
            case "history":           return "category_history"
            case "geography":           return "category_geography"
            case "music":           return "category_music"
            case "literature":           return "category_literature"
            case "technology":   return "category_technology"
            case "mythology":    return "category_mythology"
            case "festivals":    return "category_festivals"
            case "cuisine":      return "category_cuisine"
            case "trInfluencers":  return "category_tr_influencers"
            case "trPoliticians":  return "category_tr_politicians"
            case "trMemes":        return "category_tr_memes"
            case "trStreetFood":   return "category_tr_streetfood"
            case "trActors": return "category_tr_actors"
            case "custom":        return "category_custom"
            default:              return "category_custom"
            }
        } else {
            return "category_custom"
        }
    }

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
    private var textFG: Color { colorScheme == .dark ? Color.backgroundLight : Color.backgroundDark }

    init(roomCode: String) {
        self.roomCode = roomCode
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
        .swipeBack(to: MainView(), by: router)
        .sheet(isPresented: $showGuessPopup) {
            SpyGuessView(
                roomCode: roomCode,
                players: playersInPlayOrder,
                deviceId: deviceId,
                isHost: isHost,
                isPresented: $showGuessPopup,
                router: router
            )
            .environmentObject(lang)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .safeAreaInset(edge: .bottom) {
            BannerAdView()
                .background(pageBG)
                .shadow(radius: 2)
        }
        .onAppear {
            attachListeners()
            if isResultPhase(status) && amSelected {
                showGuessPopup = true
            }
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

                    let newGameId = UUID().uuidString
                    roomRef.collection("rounds").getDocuments { qs, _ in
                        qs?.documents.forEach { $0.reference.delete() }
                    }
                    roomRef.collection("guesses").getDocuments { qs, _ in
                        qs?.documents.forEach { $0.reference.delete() }
                    }

                    roomRef.updateData([
                        "info.currentRound": 1,
                        "info.currentTurnIndex": 0,
                        "info.resultText": FieldValue.delete(),
                        "info.gameId": newGameId
                    ])
                }
            }
            else if !isGameStatus(new) && new != "guessing" && new != "guessReady" && new != "result" {
                markRoleAs(revealStatus: false)
                router.replace(with: RoomView(roomCode: roomCode))
            }
        }
        .onChange(of: currentTurnIndex) { _, _ in
            maybeShowTurnSplash()
        }
        .onChange(of: turnOrder) { _, _ in
            maybeShowTurnSplash()
        }
        .onChange(of: status) { _, _ in
            maybeShowTurnSplash()
        }
        .onChange(of: continuePressed) { _, new in
            if new { maybeShowTurnSplash() }
        }
        .slidingPage(
            isPresented: $showTurnSplash,
            text: String.localized(key: "your_turn", code: lang.code)
        )
        .slidingPage(
            isPresented: $isGuessTime,
            text: String.localized(key: "guess_the_spy", code: lang.code)
        )
        .confirmPopup(
            isPresented: $showEndGameConfirm,
            title: String.localized(key: "confirm_end_title", code: lang.code),
            message: String.localized(key: "confirm_end_message", code: lang.code),
            confirmTitle: String.localized(key: "confirm_end_confirm", code: lang.code),
            cancelTitle: String.localized(key: "confirm_end_cancel", code: lang.code),
            isDestructive: true
        ) {
            endGameAndReset()
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
                    Text(String.localized(key: "room_title_with_code", code: lang.code, roomCode))
                }
                .font(.body)
                .foregroundColor(.primary)
            }
            .layoutPriority(2)

            Spacer(minLength: 8)
            
            StatusBadge(status: status)
                .layoutPriority(3)
            
            if isHost && isGameStatus(status) {
                Button {
                    showEndGameConfirm = true
                } label: {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.errorRed)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .accessibilityLabel(Text("End game"))
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
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded { isWordFieldFocused = false }
            )
            .gesture(
                DragGesture().onChanged { _ in
                    if isWordFieldFocused { isWordFieldFocused = false }
                }
            )
        }
    }

    @ViewBuilder
    private func headerRound() -> some View {
        Text(
            .init(
                String.localized(key: "round_progress", code: lang.code, currentRound, totalRounds)
            )
        )
        .font(.callout)
        .foregroundColor(.primary)
    }

    @ViewBuilder
    private func notSelectedCard() -> some View {
        VStack(spacing: 8) {
            Text("not_selected")
                .font(.body)
                .foregroundColor(.secondary)

            ButtonText(title: "back_to_room") {
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
                    Text(String.localized(key: "revealing_in_seconds", code: lang.code, countdown))
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
                Text(roleTitleTextLocalized)
                    .font(.title3).bold()
                    .foregroundColor(.primary)
                
                if !iAmSpy, let word = gameWord {
                    Text(String.localized(key: "game_word", code: lang.code, word))
                        .font(.body)
                        .foregroundColor(.primaryBlue)
                }

                ButtonText(title: "continue") {
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
            HStack {
                headerRound()
                
                Spacer(minLength: 8)
                
                if let key = categoryTitleKey {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                        Text(key)
                            .font(.caption).bold()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundColor(.primary)
                    .background(Color.primaryBlue.opacity(0.5))
                    .cornerRadius(999)
                }
            }
            
            Divider()
            
            if selectedPlayers.isEmpty {
                Text("no_players")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    ForEach(Array(playersInPlayOrder.enumerated()), id: \.element.id) { idx, p in
                        let isCurrent = (p.id == currentTurnPlayerId)
                        let roundsForPlayer: [Int: String] =
                            Dictionary(uniqueKeysWithValues:
                                playerInputs.keys.sorted().compactMap { r in
                                    if let word = playerInputs[r]?[p.id] { return (r, word) } else { return nil }
                                }
                            )

                        playerCard(
                            index: idx + 1,
                            player: p,
                            wordsByRound: roundsForPlayer,
                            isCurrentTurn: isCurrent
                        )
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(cardBG)
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    @ViewBuilder
    private func myTurnInputCard() -> some View {
        if turnOrder.indices.contains(currentTurnIndex),
           turnOrder[currentTurnIndex] == deviceId,
           status != "guessReady", status != "result" {
            VStack(spacing: 12) {
                TextField(String.localized(key: "enter_word", code: lang.code), text: $myWordInput)
                    .font(.body)
                    .padding()
                    .background(cardBG)
                    .cornerRadius(8)
                    .foregroundColor(.primary)
                    .shadow(color: .black.opacity(0.05), radius: 4)
                    .clearButton($myWordInput)
                    .focused($isWordFieldFocused)
                
                ButtonText(title: "send_word") {
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
            
            ButtonText(
                title: "guess_the_spy",
                action: { showGuessPopup = true },
                backgroundColor: .primaryBlue,
                textColor: .white,
                cornerRadius: 12,
                size: .big
            )
            .padding()
            .onAppear {
                self.isGuessTime = true
            }
        } else if status == "result" {
            
            ButtonText(
                title: "see_result",
                action: { showGuessPopup = true },
                backgroundColor: .primaryBlue,
                textColor: .white,
                cornerRadius: 12,
                size: .big
            )
            .padding()
        }
    }

    private var roleTitleTextLocalized: String {
        switch myRole {
        case "spy":     return String.localized(key: "spy", code: lang.code)
        case "knower":  return String.localized(key: "knower", code: lang.code)
        default:        return String.localized(key: "pending_role", code: lang.code)
        }
    }
}

// MARK: - Player Card
extension GameDetailView {
    @ViewBuilder
    func playerCard(index: Int,
                    player: PlayerRow,
                    wordsByRound: [Int: String],
                    isCurrentTurn: Bool) -> some View {

        let isMe = player.id == deviceId

        // arka plan — seninki yeşil, diğerleri yumuşak mavi
        let softBG: Color = {
            if isMe {
                return colorScheme == .dark
                    ? Color.successGreen.opacity(0.28)
                    : Color.successGreen.opacity(0.18)
            } else {
                return colorScheme == .dark
                    ? Color.secondaryBlue.opacity(0.22)
                    : Color.secondaryBlue.opacity(0.12)
            }
        }()

        // metin rengi — açık zeminlerde koyu, koyu zeminlerde beyaz
        let textColor: Color = colorScheme == .dark ? .white : .primary

        // pulse rengi — senin kartında yeşil, diğerlerinde mavi
        let pulseColor: Color = isMe ? .successGreen : .primaryBlue

        let base = VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(index)")
                    .font(.caption).bold()
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(textColor.opacity(0.20))
                    .foregroundColor(textColor)
                    .clipShape(Capsule())

                Text(player.name)
                    .font(.body).bold()
                    .foregroundColor(textColor)

                Spacer(minLength: 0)
            }

            ForEach(wordsByRound.keys.sorted(), id: \.self) { round in
                if let w = wordsByRound[round] {
                    Text("R\(round): \(w)")
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.9))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(softBG)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        if isCurrentTurn && status == "the game" {
            base
            .overlay(
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let phase = (sin((t * (2 * .pi)) / 1.6) + 1) * 0.5
                    let opacity = 0.25 + 0.75 * phase
                    let width   = 2.0 + 2.0 * phase

                    return RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(pulseColor.opacity(opacity), lineWidth: width)
                        .shadow(color: pulseColor.opacity(0.35 * phase),
                                radius: 8 * phase, x: 0, y: 2 * phase)
                }
            )
        } else {
            base
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(pulseColor.opacity(colorScheme == .dark ? 0.35 : 0.25),
                                  lineWidth: 1.5)
            )
        }
    }
}


// MARK: - Logic & Firestore
extension GameDetailView {
    private var currentTurnPlayerId: String? {
        guard turnOrder.indices.contains(currentTurnIndex) else { return nil }
        return turnOrder[currentTurnIndex]
    }
    
    private var isMyTurn: Bool {
        turnOrder.indices.contains(currentTurnIndex)
        && turnOrder[currentTurnIndex] == deviceId
        && status != "guessReady"
        && continuePressed
    }
    
    private var playersInPlayOrder: [PlayerRow] {
        let selectedIds = Set(selectedPlayers.map { $0.id })
        let orderedIds = turnOrder.filter { selectedIds.contains($0) }
        var list = orderedIds.compactMap { id in selectedPlayers.first { $0.id == id } }
        for p in selectedPlayers where !orderedIds.contains(p.id) { list.append(p) }
        return list
    }

    private func maybeShowTurnSplash() {
        guard continuePressed, isMyTurn else { return }
        let key = "\(currentRound)#\(currentTurnIndex)"
        if lastSplashKey != key {
            lastSplashKey = key
            showTurnSplash = true
        }
    }
    
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
                self.errorMessage = String.localized(key: "room_info_error", code: lang.code)
                self.isLoading = false
                return
            }
            self.status = (info["status"] as? String) ?? "started"
            self.hostId = (info["hostId"] as? String) ?? ""
            self.gameWord = info["word"] as? String
            self.gameId = (info["gameId"] as? String) ?? self.gameId
            
            self.currentRound = (info["currentRound"] as? Int) ?? 1
            self.totalRounds = (info["totalRounds"] as? Int) ?? 3
            self.turnOrder = (info["turnOrder"] as? [String]) ?? []
            self.currentTurnIndex = (info["currentTurnIndex"] as? Int) ?? 0
            self.spyCount = (info["spyCount"] as? Int) ?? 1
            self.categoryRaw = info["category"] as? String

            self.maybeShowTurnSplash()
            
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

            self.selectedPlayers = picked
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
    
    private func revealKey() -> String {
        if gameId.isEmpty {
            return "roleRevealed-\(roomCode)-\(deviceId)"
        } else {
            return "roleRevealed-\(roomCode)-\(gameId)-\(deviceId)"
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
        UserDefaults.standard.set(revealStatus, forKey: revealKey())
    }

    private func hasSeenRole() -> Bool {
        UserDefaults.standard.bool(forKey: revealKey())
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
                self.isGuessTime = true
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
        lastSplashKey = nil

        // role reveal flag’i sıfırla (aynı odada yeni oyunda tekrar gösterilsin)
        markRoleAs(revealStatus: false)
    }
}

// MARK: - SpyGuessView
struct SpyGuessView: View {
    @EnvironmentObject var lang: LanguageManager

    let roomCode: String
    let players: [GameDetailView.PlayerRow]
    let deviceId: String
    let isHost: Bool
    @Binding var isPresented: Bool
    var router: Router

    @State private var roomStatus: String = ""
    @State private var selectedIds: Set<String> = []
    @State private var votes: [String: [String]] = [:]
    @State private var resultText: String? = nil
    @State private var spyCount: Int = 1
    @State private var guessedSpyIds: Set<String> = []

    @State private var spyWordGuesses: [String:String] = [:]
    @State private var wordRevealed: Bool = false
    @State private var actualWord: String? = nil

    @State private var showGuessSheet: Bool = false
    @State private var mySpyGuess: String = ""

    @State private var showFinishVotingConfirm = false

    @Environment(\.colorScheme) var colorScheme
    private var cardBG: Color { colorScheme == .dark ? Color.black : Color.white }

    // convenience
    private var iAmSpy: Bool {
        players.first(where: { $0.id == deviceId })?.role == "spy"
    }
    private var alreadyGuessed: Bool {
        spyWordGuesses[deviceId] != nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 16) {
                if (roomStatus == "result" || resultText != nil), let result = resultText {
                    // result
                    Text(result)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.primaryBlue)
                        .cornerRadius(12)
                        .multilineTextAlignment(.center)
                        .onAppear {
                            Task { @MainActor in
                                let root = UIApplication.shared.topMostViewController()
                                _ = try await AdsManager.shared.showRewarded(from: root, chance: 75)
                                
                                let db = Firestore.firestore()
                                let snap = try? await db.collection("rooms").document(roomCode).getDocument()
                                if let info = snap?.data()?["info"] as? [String: Any],
                                   let st = (info["status"] as? String)?.lowercased(),
                                   st == "waiting" {
                                    router.replace(with: RoomView(roomCode: roomCode))
                                }
                            }
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(players) { p in
                            HStack(spacing: 8) {
                                Text("\(p.name) - \(localizedRole(p.role))")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                if guessedSpyIds.contains(p.id) {
                                    Image(systemName: "target")
                                        .foregroundColor(.primaryBlue)
                                        .imageScale(.medium)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(cardBG)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("spy_guesses_title")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(players.filter { $0.role == "spy" }) { spy in
                            HStack(spacing: 6) {
                                Text(spy.name)
                                    .font(.body).bold()
                                    .foregroundColor(.primary)
                                Text("—")
                                if let g = spyWordGuesses[spy.id], !g.isEmpty {
                                    Text("“\(g)”")
                                        .font(.body)
                                        .foregroundColor(.primaryBlue)
                                } else {
                                    Text("spy_guess_pending")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBG)
                    .cornerRadius(12)
                    
                    if isHost && !wordRevealed {
                        ButtonText(title: "reveal_secret_word") {
                            revealWordAndFinalize()
                        }
                        .padding(.top, 4)
                    }
                    
                    if wordRevealed, let w = actualWord {
                        HStack(spacing: 8) {
                            Image(systemName: "eye")
                            Text(String.localized(key: "revealed_secret_word", code: lang.code, w))
                        }
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBG)
                        .cornerRadius(12)
                    }
                    
                    // NEW: Spy self action - guess button (only spies, single-shot)
                    if iAmSpy && !alreadyGuessed {
                        ButtonText(title: "spy_guess_word") {
                            showGuessSheet = true
                        }
                        .padding(.top, 4)
                    }
                    
                    // Existing: host end game
                    if isHost {
                        ButtonText(title: "end_game") {
                            endGame()
                        }
                        .padding(.top, 4)
                    }
                    
                } else if roomStatus == "guessing" || roomStatus == "guessReady" {
                    // counter
                    HStack {
                        Spacer()
                        Text("\(votes.count)/\(players.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // VOTING (unchanged)
                    Text("who_is_the_spy")
                        .font(.title2).bold()
                        .foregroundColor(.primary)

                    ForEach(players) { p in
                        Button {
                            if selectedIds.contains(p.id) {
                                selectedIds.remove(p.id)
                            } else if selectedIds.count < spyCount {
                                selectedIds.insert(p.id)
                            }
                        } label: {
                            HStack {
                                Text(p.name).foregroundColor(.primary)
                                Spacer()
                                let count = voteCount(for: p.id)
                                if count > 0 {
                                    Text("\(count)")
                                        .padding(6)
                                        .background(Color.primaryBlue)
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                }
                                Image(systemName: selectedIds.contains(p.id) ? "checkmark.circle.fill" : "circle")
                            }
                            .padding()
                            .background(
                                selectedIds.contains(p.id)
                                ? Color.secondaryBlue.opacity(0.8)
                                : Color.secondaryBlue.opacity(0.15)
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(votes[deviceId] != nil)
                    }

                    if votes[deviceId] == nil, selectedIds.count == spyCount {
                        ButtonText(title: "vote") { castVotes(Array(selectedIds)) }
                    }

                    if votes[deviceId] == nil, selectedIds.count < spyCount {
                        Text(String.localized(key: "select_n_players", code: lang.code, spyCount))
                            .foregroundColor(.secondary)
                    } else if votes[deviceId] != nil, votes.count != players.count {
                        Text("voted_waiting_others")
                            .foregroundColor(.secondary)
                    }

                    if votes.count == players.count {
                        Text("all_voted_waiting_host")
                            .foregroundColor(.secondary)
                    }

                    if isHost {
                        ButtonText(title: "finish_voting") {
                            let total = players.count
                            let voted = votes.count
                            if voted < total {
                                showFinishVotingConfirm = true
                            } else {
                                showResult()
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .padding()
                }
            }
            .padding()
            .frame(maxWidth: 360)
            .background(cardBG)
            .cornerRadius(16)
            .shadow(radius: 12)
        }
        .onAppear {
            attachGuessListener()
        }
        .confirmPopup(
            isPresented: $showFinishVotingConfirm,
            title: String.localized(key: "confirm_finish_title", code: lang.code),
            message: String.localized(
                key: "confirm_finish_message_fmt",
                code: lang.code,
                votes.count,
                players.count 
            ),
            confirmTitle: String.localized(key: "confirm_finish_confirm", code: lang.code),
            cancelTitle: String.localized(key: "confirm_finish_cancel", code: lang.code),
            isDestructive: true
        ) {
            showResult()
        }
        .sheet(isPresented: $showGuessSheet) {
            NavigationView {
                VStack(spacing: 12) {
                    TextField(String.localized(key: "enter_guess", code: lang.code), text: $mySpyGuess)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    ButtonText(title: "submit_guess") {
                        submitSpyGuess()
                    }
                    .disabled(mySpyGuess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding()
                .navigationTitle(Text("spy_guess_word"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Helpers
    private func localizedRole(_ role: String?) -> String {
        switch role {
        case "spy":
            return String.localized(key: "spy", code: lang.code)
        case "knower":
            return String.localized(key: "knower", code: lang.code)
        case .some(let r) where !r.isEmpty:
            return r
        default:
            return String.localized(key: "unknown", code: lang.code)
        }
    }

    private func voteCount(for targetId: String) -> Int {
        votes.values.flatMap { $0 }.filter { $0 == targetId }.count
    }

    private func endGame() {
        isPresented = false
        router.replace(with: RoomView(roomCode: roomCode))

        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)
        roomRef.updateData([
            "info.status": "waiting",
            "info.currentRound": 1,
            "info.currentTurnIndex": 0,
            "info.resultText": FieldValue.delete(),
            "info.spyWordGuesses": FieldValue.delete(),
            "info.wordRevealed": FieldValue.delete(),
            "info.guessedSpyIds": FieldValue.delete()
        ])

        roomRef.collection("rounds").getDocuments { qs, _ in
            qs?.documents.forEach { $0.reference.delete() }
        }
        roomRef.collection("guesses").getDocuments { qs, _ in
            qs?.documents.forEach { $0.reference.delete() }
        }
    }

    // MARK: - Firestore listeners
    private func attachGuessListener() {
        let db = Firestore.firestore()
        let ref = db.collection("rooms").document(roomCode).collection("guesses")

        // votes (existing)
        ref.addSnapshotListener { qs, _ in
            var dict: [String: [String]] = [:]
            qs?.documents.forEach { doc in
                let data = doc.data()
                if let arr = data["votes"] as? [String] {
                    dict[doc.documentID] = arr
                } else if let single = data["vote"] as? String {
                    dict[doc.documentID] = [single]
                }
            }
            self.votes = dict
        }

        // room info (extended)
        let roomRef = db.collection("rooms").document(roomCode)
        roomRef.addSnapshotListener { snap, _ in
            if let data = snap?.data(),
               let info = data["info"] as? [String: Any] {

                if let ids = info["guessedSpyIds"] as? [String] {
                    self.guessedSpyIds = Set(ids)
                } else {
                    self.guessedSpyIds = []
                }

                self.roomStatus = (info["status"] as? String) ?? ""
                self.spyCount = (info["spyCount"] as? Int) ?? 1
                self.actualWord = info["word"] as? String
                self.wordRevealed = (info["wordRevealed"] as? Bool) ?? false

                if let guesses = info["spyWordGuesses"] as? [String:String] {
                    self.spyWordGuesses = guesses
                } else {
                    self.spyWordGuesses = [:]
                }

                let newResult = info["resultText"] as? String
                self.resultText = (self.roomStatus == "result") ? newResult : nil
            }
        }
    }

    // MARK: - Actions
    private func castVotes(_ targetIds: [String]) {
        let db = Firestore.firestore()
        let ref = db.collection("rooms")
            .document(roomCode)
            .collection("guesses")
            .document(deviceId)

        ref.setData(["votes": targetIds])
    }

    private func submitSpyGuess() {
        let trimmed = mySpyGuess.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)

        // Safer nested update for a single key in the dictionary
        roomRef.updateData([
            "info.spyWordGuesses.\(deviceId)": trimmed
        ]) { _ in
            self.showGuessSheet = false
            self.mySpyGuess = ""
        }
    }

    private func revealWordAndFinalize() {
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)

        // Decide if spies guessed correctly (case-insensitive, trimmed)
        let word = (actualWord ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let spiesHit = spyWordGuesses.values.contains(where: { guess in
            normalize(guess) == normalize(word)
        })

        var updates: [String:Any] = ["info.wordRevealed": true]

        if spiesHit {
            // override result text in favor of spies
            updates["info.resultText"] = String.localized(key: "result_spies_win_by_guess", code: lang.code)
        }

        roomRef.updateData(updates)
    }

    private func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Existing tally → result calc for voted spies (unchanged)
    private func showResult() {
        guard !players.isEmpty else { return }

        var tally: [String:Int] = [:]
        votes.values.flatMap { $0 }.forEach { tally[$0, default: 0] += 1 }

        let ordered = tally.sorted { $0.value > $1.value }.map { $0.key }
        let topN = Array(ordered.prefix(max(0, spyCount)))

        let actualSpies = Set(players.compactMap { $0.role == "spy" ? $0.id : nil })
        let found = Set(topN)
        let allCaught = found == actualSpies
        let anyCaught = !found.intersection(actualSpies).isEmpty

        if allCaught {
            resultText = String.localized(key: "result_all_spies_found", code: lang.code)
        } else if anyCaught {
            resultText = String.localized(key: "result_some_spies_found", code: lang.code)
        } else {
            resultText = String.localized(key: "result_spies_escaped", code: lang.code)
        }

        self.roomStatus = "result"

        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)
        roomRef.updateData([
            "info.status": "result",
            "info.resultText": resultText as Any,
            "info.guessedSpyIds": topN
        ])

        self.guessedSpyIds = Set(topN)
    }
}

