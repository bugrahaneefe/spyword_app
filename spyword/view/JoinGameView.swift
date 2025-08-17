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
        VStack(spacing: 0) {
            // Top bar with back button
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
            }
            .padding()
            .background(Color.backgroundLight)
            .shadow(radius: 2)

            Divider()

            // Main content
            VStack(spacing: 24) {
                Text("join_room_title")
                    .font(.h2)
                    .foregroundColor(.primaryBlue)

                // A) Son Odalar
                if !recent.codes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("recent_rooms")
                            .font(.h2)
                            .foregroundColor(.black)

                        List {
                            ForEach(recent.codes, id: \.self) { code in
                                HStack {
                                    Text(code)
                                        .font(.body)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color.backgroundLight)
                                        .cornerRadius(8)
                                    Spacer()
                                    Button("join_button") {
                                        rejoin(code)
                                    }
                                    .font(.button)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 16)
                                    .background(Color.primaryBlue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let code = recent.codes[index]
                                    leaveRoom(code: code)
                                }
                                recent.remove(at: indexSet)
                            }
                        }
                        .listStyle(.plain) // düz görünüm
                    }
                    .frame(height: 200)
                    .padding(.bottom, 16)
                }

                // B) Yeni Odaya Giriş
                VStack(spacing: 16) {
                    TextField("room_code_placeholder", text: $roomCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .font(.body)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.05), radius: 4)

                    TextField("nickname_placeholder", text: $nickname)
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
                        title: isLoading ? "loading_text" : "join_button",
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
    }

    // MARK: - Join flows

    private func joinNew() {
        errorMessage = nil
        roomCode = roomCode.uppercased()
        guard roomCode.count == 6 else {
            errorMessage = NSLocalizedString("invalid_room_code_error", comment: "")
            return
        }
        let name = nickname.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            errorMessage = NSLocalizedString("empty_nickname_error", comment: "")
            return
        }

        isLoading = true
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)

        // 1) Oda var mı?
        roomRef.getDocument { snap, err in
            guard err == nil, let snap = snap, snap.exists else {
                finish(error: NSLocalizedString("room_not_found_error", comment: ""))
                return
            }

            // 2) Host hazır mı?
            checkHostReady(roomRef: roomRef) { ready in
                guard ready else {
                    finish(error: NSLocalizedString("host_not_ready_error", comment: ""))
                    return
                }

                // 3) Oyuncu kaydı
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
                            finish(error: String(format: NSLocalizedString("join_failed_error", comment: ""), err.localizedDescription))
                        } else {
                            isLoading = false
                            recent.add(roomCode)
                            routeToCurrentState(code: roomCode)
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

        roomRef.getDocument { snap, err in
            guard err == nil, let snap = snap, snap.exists else {
                finish(error: NSLocalizedString("room_not_found_error", comment: ""))
                return
            }

            checkHostReady(roomRef: roomRef) { ready in
                guard ready else {
                    finish(error: NSLocalizedString("host_not_ready_error", comment: ""))
                    return
                }

                isLoading = false
                recent.add(code.uppercased())
                routeToCurrentState(code: code.uppercased())
            }
        }
    }
    
    private func leaveRoom(code: String) {
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(code)

        // Önce oda bilgilerini oku
        roomRef.getDocument { snap, _ in
            guard let data = snap?.data(),
                  let info = data["info"] as? [String: Any],
                  let hostId = info["hostId"] as? String else { return }

            if hostId == deviceId {
                // Ben host isem: Odayı tamamen sil
                roomRef.delete { err in
                    if let err = err {
                        print("Oda silinemedi: \(err)")
                    } else {
                        print("Oda tamamen silindi.")
                    }
                }
            } else {
                // Host değilsem: sadece oyuncu kaydımı sil
                roomRef.collection("players").document(deviceId).delete { err in
                    if let err = err {
                        print("Oyuncu kaydı silinemedi: \(err)")
                    } else {
                        print("Oyuncu odadan ayrıldı.")
                    }
                }
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
                    self.router.replace(with: GameDetailView(roomCode: code))
                } else {
                    self.router.replace(with: RoomView(roomCode: code))
                }

            case "arranging":
                if hostId == self.deviceId {
                    // host geri döndü: seçim varsa ayar ekranına, yoksa seçim ekranına
                    let vm = RoomViewModel(roomCode: code)
                    if !locked.isEmpty {
                        self.router.replace(with: GameSettingsView(vm: vm, roomCode: roomCode, selectedIds: locked))
                    } else {
                        self.router.replace(with: SelectPlayersView(roomCode: code, vm: vm))
                    }
                } else {
                    self.router.replace(with: RoomView(roomCode: code))
                }

            default: // waiting
                self.router.replace(with: RoomView(roomCode: code))
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
