import SwiftUI
import Firebase

struct GameSettings {
    enum WordMode { case random, custom }
    var mode: WordMode
    var customWord: String?          // mode == .custom ise zorunlu
    var spyCount: Int
    var totalRounds: Int
}

final class RoomViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var hostId: String?
    @Published var status: String = "waiting"
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var chosen: Set<String> = []
    @Published var mode: GameSettings.WordMode = .random
    @Published var customWord: String = ""
    @Published var spyCount: Int = 1
    @Published var totalRounds: Int = 3
    private let roomCode: String
    private var roomListener: ListenerRegistration?
    private var playersListener: ListenerRegistration?

    private var roomRef: DocumentReference {
        Firestore.firestore().collection("rooms").document(roomCode)
    }

    init(roomCode: String) {
        self.roomCode = roomCode
        startListeners()
    }

    deinit {
        roomListener?.remove()
        playersListener?.remove()
    }

    // MARK: - Realtime listeners (aynı + status okuma)
    private func startListeners() {
        roomListener = roomRef.addSnapshotListener { snap, error in
            if let data = snap?.data(),
               let info = data["info"] as? [String:Any] {
                DispatchQueue.main.async {
                    self.hostId = info["hostId"] as? String
                    self.status  = (info["status"] as? String) ?? "waiting"
                    self.isLoading = false
                }
            } else if let err = error {
                DispatchQueue.main.async {
                    self.errorMessage = err.localizedDescription
                    self.isLoading = false
                }
            }
        }

        playersListener = roomRef.collection("players")
            .addSnapshotListener { snap, error in
                if let docs = snap?.documents {
                    let loaded = docs.map { doc -> Player in
                        let d = doc.data()
                        return Player(
                            id: doc.documentID,
                            name: d["name"] as? String ?? "Anonim",
                            role: d["role"] as? String,
                            isEliminated: d["isEliminated"] as? Bool,
                            isSelected: d["isSelected"] as? Bool
                        )
                    }
                    DispatchQueue.main.async { self.players = loaded }
                } else if let err = error {
                    DispatchQueue.main.async { self.errorMessage = err.localizedDescription }
                }
            }
    }

    // MARK: - Status helpers
    func setStatus(_ value: String) {
        roomRef.setData(["info": ["status": value]], merge: true)
    }

    func beginArranging() {
        setStatus("arranging")
    }

    // MARK: - Selection persist (status değişmez!)
    func saveSelection(_ selectedIds: [String], completion: ((Error?) -> Void)? = nil) {
        let batch = Firestore.firestore().batch()
        let setSelected: Set<String> = Set(selectedIds)

        // İsteğe bağlı: info.lockedPlayers alanı
        batch.setData(["info": ["lockedPlayers": Array(setSelected)]], forDocument: roomRef, merge: true)

        for p in players {
            let doc = roomRef.collection("players").document(p.id)
            batch.updateData(["isSelected": setSelected.contains(p.id)], forDocument: doc)
        }

        batch.commit { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Start game with settings
    func startGame(selectedIds: [String], settings: GameSettings) {
        // Kelime
        let word: String = {
            switch settings.mode {
            case .random:
                // örnek havuz — kendi listenle değiştir
                let pool = ["Liman", "Kütüphane", "Seramik", "Pazar", "Rüzgar"]
                return pool.randomElement() ?? "Kelime"
            case .custom:
                return settings.customWord?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? settings.customWord!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "Kelime"
            }
        }()

        // Roller
        var eligibleForSpy = selectedIds
        if settings.mode == .custom, let host = hostId {
            // host kelimeyi girdiyse spy olamaz
            eligibleForSpy.removeAll { $0 == host }
        }

        let spyCount = max(0, min(settings.spyCount, max(0, eligibleForSpy.count)))
        let spies = Array(eligibleForSpy.shuffled().prefix(spyCount))
        let spySet = Set(spies)

        let batch = Firestore.firestore().batch()

        // Seçili olmayan herkesin role'ünü temizle (isteğe bağlı)
        for p in players {
            let doc = roomRef.collection("players").document(p.id)
            let isInGame = selectedIds.contains(p.id)
            var updates: [String:Any] = ["isSelected": isInGame]
            if isInGame {
                let role = spySet.contains(p.id) ? "spy" : "knower"
                updates["role"] = role
                updates["isEliminated"] = false
            } else {
                updates["role"] = FieldValue.delete()
            }
            batch.updateData(updates, forDocument: doc)
        }

        // Oda info
        // random sıra oluştur
        let turnOrder = selectedIds.shuffled()

        // Oda info
        var info: [String:Any] = [
            "status": "the game",
            "word": word,
            "spyCount": spyCount,
            "totalRounds": settings.totalRounds,
            "lockedPlayers": selectedIds,
            "turnOrder": turnOrder
        ]

        batch.setData(["info": info], forDocument: roomRef, merge: true)
        

        batch.commit { [weak self] error in
            if let err = error {
                DispatchQueue.main.async { self?.errorMessage = err.localizedDescription }
            }
        }
    }

    // Var olan remove() fonksiyonun aynı
    func remove(player: Player) {
        roomRef.collection("players").document(player.id).delete { [weak self] error in
            if let err = error { self?.errorMessage = err.localizedDescription }
        }
    }
}
