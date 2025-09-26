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
    @State private var isResultAdsShown = false
    
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
        var avatarName: String? = nil
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
                DescriptionText(inputKey: "game_detail_description")
                    .background(pageBG)
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
                isResultAdsShown: $isResultAdsShown,
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
                        "info.gameId": newGameId,
                        "info.continuePressed": FieldValue.delete()
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
                    } else {
                        roleRevealCard()
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
                    setContinuePressed(true)
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
                backgroundColor: .primaryBlue,
                textColor: .white,
                cornerRadius: 12,
                size: .big,
                action: { showGuessPopup = true }
            )
            .padding()
            .onAppear {
                self.isGuessTime = true
            }
        } else if status == "result" {
            
            ButtonText(
                title: "see_result",
                backgroundColor: .primaryBlue,
                textColor: .white,
                cornerRadius: 12,
                size: .big,
                action: { showGuessPopup = true }
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
        PlayerCardView(
            index: index,
            player: player,
            wordsByRound: wordsByRound,
            isCurrentTurn: isCurrentTurn,
            isMe: (player.id == deviceId),
            status: status,
            colorScheme: colorScheme,
            gameWord: gameWord,
            myRole: myRole
        )
        .environmentObject(lang)
    }
}

private struct PlayerCardView: View {
    let index: Int
    let player: GameDetailView.PlayerRow
    let wordsByRound: [Int: String]
    let isCurrentTurn: Bool
    let isMe: Bool
    let status: String
    let colorScheme: ColorScheme
    let gameWord: String?
    let myRole: String?

    @EnvironmentObject var lang: LanguageManager
    @State private var showPeek = false
    @State private var peekWork: DispatchWorkItem?

    private var textColor: Color { colorScheme == .dark ? .white : .primary }
    private var pulseColor: Color { isMe ? .successGreen : .primaryBlue }
    private var softBG: Color {
        if isMe {
            return colorScheme == .dark ? Color.successGreen.opacity(0.28) : Color.successGreen.opacity(0.18)
        } else {
            return colorScheme == .dark ? Color.secondaryBlue.opacity(0.22) : Color.secondaryBlue.opacity(0.12)
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Ana kart
            cardBody
                .overlay(borderOverlay)

            if showPeek {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { hidePeek() }
            }
            
            // Peek balonu (sadece kendi kartımda)
            if isMe {
                peekBubble
                    .opacity(showPeek ? 1 : 0)
                    .scaleEffect(showPeek ? 1 : 0.95)
                    .animation(.spring(response: 0.25, dampingFraction: 0.9), value: showPeek)
                    .padding(.top, 6)
                    .padding(.trailing, 6)
            }
        }
        .onDisappear { peekWork?.cancel() }
    }
    
    private func showPeekForAWhile() {
        // önceki zamanlayıcıyı iptal et
        peekWork?.cancel()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            showPeek = true
        }
        // 2 sn sonra otomatik gizle
        let work = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.2)) {
                showPeek = false
            }
        }
        peekWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func hidePeek() {
        peekWork?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            showPeek = false
        }
    }
    
    // MARK: - Parçalar
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Image(player.avatarName ?? "1")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                    .padding(.trailing, 2)
                
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
                
                if isMe {
                    Image(systemName: "info.circle.fill")
                        .imageScale(.large)
                        .foregroundColor(.primaryBlue)
                        .padding(6)
                        .background(Color(.systemBackground).opacity(colorScheme == .dark ? 0.15 : 0.10))
                        .clipShape(Circle())
                        .onTapGesture {
                            showPeekForAWhile()
                        }
                        .accessibilityLabel(Text("Show role"))
                }
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
    }

    private var borderOverlay: some View {
        Group {
            if isCurrentTurn && status.lowercased() == "the game" {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let phase = (sin((t * (2 * .pi)) / 1.6) + 1) * 0.5
                    let opacity = 0.25 + 0.75 * phase
                    let width   = 2.0 + 2.0 * phase

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(pulseColor.opacity(opacity), lineWidth: width)
                        .shadow(color: pulseColor.opacity(0.35 * phase), radius: 8 * phase, x: 0, y: 2 * phase)
                }
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(pulseColor.opacity(colorScheme == .dark ? 0.35 : 0.25), lineWidth: 1.5)
            }
        }
    }

    private var peekBubble: some View {
        // Rol ve (bilense) secret word
        let isSpy = (myRole == "spy")
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: isSpy ? "eye.trianglebadge.exclamationmark.fill" : "lightbulb.fill")
                    .imageScale(.small)
                Text(isSpy
                     ? String.localized(key: "spy", code: lang.code)
                     : String.localized(key: "knower", code: lang.code))
                    .font(.caption).bold()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSpy ? Color.errorRed : Color.successGreen)
            .clipShape(Capsule())

            if !isSpy, let w = gameWord, !w.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "key.fill").imageScale(.small)
                    Text(String.localized(key: "game_word", code: lang.code, w))
                        .font(.caption)
                }
                .foregroundColor(.primary)
            }
        }
        .padding(10)
        .background(colorScheme == .dark ? Color.black.opacity(0.9) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(radius: 8)
        .onTapGesture { hidePeek() }
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
        if isGuessRelated(status) {
            showTurnSplash = false
            return
        }
        
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

            if let map = info["continuePressed"] as? [String: Any],
               let mine = map[self.deviceId] as? Bool {
                if self.continuePressed != mine {
                    self.continuePressed = mine
                }
            } else {
                if self.continuePressed != false {
                    self.continuePressed = false
                }
            }
            
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
                let avatarName = d["avatarName"] as? String

                if isSelected { picked.append(.init(id: id, name: name, role: role, avatarName: avatarName)) }
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
    
    private func setContinuePressed(_ pressed: Bool) {
        continuePressed = pressed
        
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)
        roomRef.updateData([
            "info.continuePressed.\(deviceId)": pressed
        ])
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
            "info.resultText": FieldValue.delete(),
            "info.continuePressed": FieldValue.delete()
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
