import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct JoinGameView: View {
    @EnvironmentObject var router: Router
    @StateObject private var recent = RecentRoomsManager.shared

    @State private var roomCode: String = ""
    @State private var nickname: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let deviceId = UserDefaults.standard
        .string(forKey: "deviceId") ?? UUID().uuidString

    var body: some View {
        VStack(spacing: 24) {
            Text("Odaya Katıl")
                .font(.h2)
                .foregroundColor(.primaryBlue)

            // A) Son Odalar
            if !recent.codes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Son Odalar")
                        .font(.h2)
                        .foregroundColor(.black)
                    ScrollView {
                        ForEach(recent.codes, id: \.self) { code in
                            HStack {
                                Text(code)
                                    .font(.body)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.backgroundLight)
                                    .cornerRadius(8)
                                Spacer()
                                Button("Katıl") {
                                    rejoin(code)
                                }
                                .font(.button)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 16)
                                .background(Color.primaryBlue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .frame(height: 200)
                .padding(.bottom, 16)
            }

            // B) Yeni Odaya Giriş
            VStack(spacing: 16) {
                TextField("Oda Kodu (6 haneli)", text: $roomCode)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .font(.body)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.05), radius: 4)

                TextField("Nickname", text: $nickname)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .font(.body)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.05), radius: 4)

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.errorRed)
                }

                ButtonText(
                    title: isLoading ? "Bekleniyor..." : "Katıl",
                    action: joinNew,
                    backgroundColor: .primaryBlue,
                    textColor: .white,
                    cornerRadius: 12,
                    size: .big
                )
                .disabled(isLoading || roomCode.count != 6 || nickname.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Join flows

    private func joinNew() {
        errorMessage = nil
        roomCode = roomCode.uppercased()
        guard roomCode.count == 6 else {
            errorMessage = "Geçerli 6 haneli oda kodu giriniz."
            return
        }
        let name = nickname.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            errorMessage = "Lütfen bir nickname girin."
            return
        }

        isLoading = true
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)

        // 1) Oda var mı?
        roomRef.getDocument { snap, err in
            guard err == nil, let snap = snap, snap.exists else {
                finish(error: "Oda bulunamadı veya geçerli değil.")
                return
            }

            // 2) Host hazır mı? (info.hostId -> players/{hostId} var mı kontrolü)
            checkHostReady(roomRef: roomRef) { ready in
                guard ready else {
                    finish(error: "Ev sahibinin ismini girip 'İleri' basmasını bekleyin.")
                    return
                }

                // 3) Oyuncu kaydı (idempotent)
                let playerData: [String: Any] = [
                    "name": name,
                    "role": NSNull(),
                    "isEliminated": false,
                    "isSelected": false,
                    "joinedAt": FieldValue.serverTimestamp()
                ]
                roomRef.collection("players")
                    .document(deviceId)
                    .setData(playerData, merge: true) { err in
                        if let err = err {
                            finish(error: "Katılım başarısız: \(err.localizedDescription)")
                        } else {
                            isLoading = false
                            recent.add(roomCode)
                            routeToCurrentState(code: roomCode) // mevcut duruma yönlendir
                        }
                    }
            }
        }
    }

    private func rejoin(_ code: String) {
        errorMessage = nil
        isLoading = true

        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(code.uppercased())

        // Oda var mı?
        roomRef.getDocument { snap, err in
            guard err == nil, let snap = snap, snap.exists else {
                finish(error: "Oda bulunamadı veya geçerli değil.")
                return
            }

            // Host hazır mı?
            checkHostReady(roomRef: roomRef) { ready in
                guard ready else {
                    finish(error: "Ev sahibinin ismini girip 'İleri' basmasını bekleyin.")
                    return
                }

                isLoading = false
                recent.add(code.uppercased())
                routeToCurrentState(code: code.uppercased())
            }
        }
    }

    /// info.hostId'yi okuyup players/{hostId} belgesi var mı ve name alanı dolu mu diye kontrol eder.
    private func checkHostReady(roomRef: DocumentReference, completion: @escaping (Bool) -> Void) {
        roomRef.getDocument { snap, _ in
            guard let info = snap?.data()?["info"] as? [String:Any],
                  let hostId = info["hostId"] as? String else {
                completion(false); return
            }

            roomRef.collection("players").document(hostId).getDocument { hostSnap, _ in
                guard let hd = hostSnap?.data(),
                      let name = hd["name"] as? String,
                      !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                    completion(false); return
                }
                // İsteğe bağlı: rol gerçekten "host" mu?
                if let role = hd["role"] as? String, role == "host" {
                    completion(true)
                } else {
                    // rol alanı eksik olsa da isim girilmişse yine hazır sayabilirsiniz.
                    completion(true)
                }
            }
        }
    }


    // MARK: - Smart routing (status + role + selection)
    private func routeToCurrentState(code: String) {
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(code)

        // oda bilgisini ve kullanıcı dokümanını paralel okuyalım
        let group = DispatchGroup()
        var info: [String:Any]?
        var me: [String:Any]?

        group.enter()
        roomRef.getDocument { snap, _ in
            info = (snap?.data()?["info"] as? [String:Any])
            group.leave()
        }

        group.enter()
        roomRef.collection("players").document(deviceId).getDocument { snap, _ in
            me = snap?.data()
            group.leave()
        }

        group.notify(queue: .main) {
            self.isLoading = false
            guard let info = info else {
                self.errorMessage = "Oda bilgisi okunamadı."
                return
            }

            let status = (info["status"] as? String)?.lowercased() ?? "waiting"
            let hostId = info["hostId"] as? String
            let locked = (info["lockedPlayers"] as? [String]) ?? []

            let amSelected = (me?["isSelected"] as? Bool) ?? false

            switch status {
            case "the game", "started":
                if amSelected {
                    self.router.navigate(
                        to: GameDetailView(roomCode: code),
                        type: .push
                    )
                } else {
                    self.router.navigate(
                        to: RoomView(roomCode: code).withRouter(),
                        type: .push
                    )
                }

            case "arranging":
                if hostId == self.deviceId {
                    // host geri döndü: seçim varsa ayar ekranına, yoksa seçim ekranına
                    let vm = RoomViewModel(roomCode: code)
                    if !locked.isEmpty {
                        self.router.navigate(
                            to: GameSettingsView(vm: vm, selectedIds: locked).withRouter(),
                            type: .push
                        )
                    } else {
                        self.router.navigate(
                            to: SelectPlayersView(roomCode: code, vm: vm).withRouter(),
                            type: .push
                        )
                    }
                } else {
                    self.router.navigate(
                        to: RoomView(roomCode: code).withRouter(),
                        type: .push
                    )
                }

            default: // waiting
                self.router.navigate(
                    to: RoomView(roomCode: code).withRouter(),
                    type: .push
                )
            }
        }
    }

    // MARK: - Helpers
    private func finish(error: String) {
        DispatchQueue.main.async {
            self.errorMessage = error
            self.isLoading = false
        }
    }
}
