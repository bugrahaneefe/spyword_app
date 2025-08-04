import SwiftUI
import Firebase

final class RoomViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var hostId: String?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let roomCode: String
    private var roomListener: ListenerRegistration?
    private var playersListener: ListenerRegistration?

    init(roomCode: String) {
        self.roomCode = roomCode
        startListeners()
    }

    deinit {
        roomListener?.remove()
        playersListener?.remove()
    }

    private func startListeners() {
        let roomRef = Firestore.firestore().collection("rooms").document(roomCode)

        roomListener = roomRef.addSnapshotListener { snap, error in
            if let data = snap?.data(),
               let info = data["info"] as? [String:Any],
               let h = info["hostId"] as? String {
                DispatchQueue.main.async {
                    self.hostId = h
                    self.isLoading = false
                }
            } else if let err = error {
                DispatchQueue.main.async {
                    self.errorMessage = err.localizedDescription
                    self.isLoading = false
                }
            }
        }

        playersListener = roomRef
            .collection("players")
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
                    DispatchQueue.main.async {
                        self.players = loaded
                    }
                } else if let err = error {
                    DispatchQueue.main.async {
                        self.errorMessage = err.localizedDescription
                    }
                }
            }
    }

    func remove(player: Player) {
        Firestore.firestore()
            .collection("rooms")
            .document(roomCode)
            .collection("players")
            .document(player.id)
            .delete { error in
                if let err = error {
                    DispatchQueue.main.async {
                        self.errorMessage = err.localizedDescription
                    }
                }
            }
    }
}
