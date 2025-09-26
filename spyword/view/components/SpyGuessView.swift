import SwiftUI
import Firebase

// MARK: - SpyGuessView
struct SpyGuessView: View {
    @EnvironmentObject var lang: LanguageManager

    let roomCode: String
    let players: [GameDetailView.PlayerRow]
    let deviceId: String
    let isHost: Bool
    @Binding var isPresented: Bool
    @Binding var isResultAdsShown: Bool
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
                        .padding(.horizontal)
                        .background(Color.primaryBlue)
                        .cornerRadius(12)
                        .multilineTextAlignment(.center)
                        .onAppear {
                            Task { @MainActor in
                                let root = UIApplication.shared.topMostViewController()
                                _ = try await AdsManager.shared.showRewarded(from: root, chance: isResultAdsShown ? 0 : 80)
                                isResultAdsShown = true
                                let db = Firestore.firestore()
                                let snap = try? await db.collection("rooms").document(roomCode).getDocument()
                                if let info = snap?.data()?["info"] as? [String: Any],
                                   let st = (info["status"] as? String)?.lowercased(),
                                   st == "waiting" {
                                    router.replace(with: RoomView(roomCode: roomCode))
                                }
                            }
                        }

                    // MARK: Players & roles (SCROLLABLE + CLEAR ROLES)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("players")
                            .font(.headline)
                            .foregroundColor(.primary)

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(players) { p in
                                    PlayerResultRow(
                                        name: p.name,
                                        role: p.role,
                                        isGuessedTarget: guessedSpyIds.contains(p.id),
                                        colorScheme: colorScheme,
                                        isMe: (p.id == deviceId),
                                        enablePulse: (roomStatus == "result") && (p.id == deviceId)
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxHeight: 240)
                    }
                    .background(cardBG)
                    .cornerRadius(12)

                    // MARK: Spy guesses
                    VStack(alignment: .leading, spacing: 10) {
                        Text("spy_guesses_title")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(players.filter { $0.role == "spy" }) { spy in
                                    HStack(spacing: 8) {
                                        RoleBadge(role: "spy")
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
                        }
                        .frame(maxHeight: 160)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBG)
                    .cornerRadius(12)

                    // Reveal button (unchanged)
                    if isHost && !wordRevealed {
                        ButtonText(title: "reveal_secret_word", size: .justCaption) {
                            revealWordAndFinalize()
                        }
                    }

                    // Revealed word (unchanged)
                    if wordRevealed, let w = actualWord {
                        HStack(alignment: .center,spacing: 8) {
                            Spacer()
                            Image(systemName: "eye")
                            Text(String.localized(key: "revealed_secret_word", code: lang.code, w))
                            Spacer()
                        }
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBG)
                        .cornerRadius(12)
                    }

                    // Spy self action (unchanged)
                    if iAmSpy && !alreadyGuessed {
                        ButtonText(title: "spy_guess_word", size: .justCaption) {
                            showGuessSheet = true
                        }
                        .padding(.top, 2)
                    }

                    // Host end game (unchanged)
                    if isHost {
                        ButtonText(title: "end_game", size: .justCaption) {
                            endGame()
                        }
                        .padding(.top, 2)
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

// MARK: - UI Helpers (Result Screen)

private func roleIconName(for role: String?) -> String {
    switch role?.lowercased() {
    case "spy":     return "eye.trianglebadge.exclamationmark.fill"
    case "knower":  return "lightbulb.fill"
    default:        return "questionmark.circle.fill"
    }
}

private func roleTint(for role: String?, _ colorScheme: ColorScheme) -> Color {
    switch role?.lowercased() {
    case "spy":     return Color.errorRed
    case "knower":  return Color.successGreen
    default:        return colorScheme == .dark ? .gray : .secondary
    }
}

private struct RoleBadge: View {
    var role: String?
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var lang: LanguageManager
    
    var body: some View {
        let tint = roleTint(for: role, colorScheme)
        HStack(spacing: 6) {
            Image(systemName: roleIconName(for: role))
                .imageScale(.small)
            Text(roleLabel(role))
                .font(.caption).bold()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(.white)
        .background(tint)
        .clipShape(Capsule())
        .accessibilityLabel(roleLabel(role))
    }

    private func roleLabel(_ role: String?) -> String {
        switch role?.lowercased() {
        case "spy":     return String.localized(key: "spy", code: lang.code)
        case "knower":  return String.localized(key: "knower", code: lang.code)
        default:        return String.localized(key: "unknown", code: lang.code)
        }
    }
}

private struct PlayerResultRow: View {
    var name: String
    var role: String?
    var isGuessedTarget: Bool
    var colorScheme: ColorScheme
    var isMe: Bool = false
    var enablePulse: Bool = false
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        // spy kırmızı, diğer herkes primaryBlue
        let isSpy = role?.lowercased() == "spy"
        let tint: Color = isSpy ? Color.errorRed : Color.primaryBlue
        let bg = (colorScheme == .dark ? tint.opacity(0.16) : tint.opacity(0.12))

        let base = HStack(spacing: 10) {
            RoleBadge(role: role)
            Text(name)
                .font(.body).bold()
                .foregroundColor(.primary)

            Spacer(minLength: 0)

            if isGuessedTarget {
                HStack(spacing: 6) {
                    Image(systemName: "target").imageScale(.medium)
                    Text(String.localized(key: "guessed", code: lang.code))
                        .font(.caption).bold()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundColor(.white)
                .background(Color.primaryBlue)
                .clipShape(Capsule())
                .accessibilityLabel("Guessed as spy")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        // Border: kendi kartım ve pulse açık ise animasyonlu; değilse normal
        Group {
            if isMe && enablePulse {
                base.overlay(
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let phase = (sin((t * (2 * .pi)) / 1.6) + 1) * 0.5
                        let opacity = 0.25 + 0.75 * phase
                        let width   = 2.0 + 2.0 * phase

                        return RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(tint.opacity(opacity), lineWidth: width)
                            .shadow(color: tint.opacity(0.35 * phase),
                                    radius: 8 * phase, x: 0, y: 2 * phase)
                    }
                )
            } else {
                base.overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(isGuessedTarget ? 1.0 : (colorScheme == .dark ? 0.45 : 0.35)),
                                      lineWidth: isGuessedTarget ? 2.0 : 1.0)
                )
            }
        }
    }
}
