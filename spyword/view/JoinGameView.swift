import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct JoinGameView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var recent = RecentRoomsManager.shared
    
    @State private var roomCode: String = ""
    @State private var nickname: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let deviceId = UserDefaults.standard
        .string(forKey: "deviceId") ?? UUID().uuidString

    // MARK: - Body
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        router.replace(with: MainView())
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("main_menu")
                        }
                        .font(.body)
                        .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding()
                .background(colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
                .shadow(radius: 2)

                Divider()

                VStack(spacing: 24) {
                    Text("join_room_title")
                        .font(.h2)
                        .foregroundColor(.primary)
                        .padding(.top, 8)

                    if !recent.codes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("recent_rooms")
                                .font(.button)
                                .foregroundColor(.primary)

                            ScrollView {
                                ForEach(recent.codes, id: \.self) { code in
                                    HStack(spacing: 12) {
                                        Button {
                                            leaveRoom(code: code)
                                            if let idx = recent.codes.firstIndex(of: code) {
                                                recent.remove(at: IndexSet(integer: idx))
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.errorRed)
                                                .font(.caption)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text(code)
                                            .font(.body)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(colorScheme == .dark ? Color.black : Color.white)
                                            .cornerRadius(8)
                                            .foregroundColor(.primary)
                                            .shadow(color: .black.opacity(0.05), radius: 4)

                                        Spacer()

                                        Button("join_button") {
                                            rejoin(code)
                                        }
                                        .font(.body)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 16)
                                        .background(Color.primaryBlue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                    .onTapGesture {
                                        rejoin(code)
                                    }
                                    .listRowBackground((colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight).opacity(0.001))
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .frame(height: 200)
                        }
                    }

                    Divider()
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        TextField("room_code_placeholder", text: $roomCode)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                            .font(.body)
                            .padding()
                            .background(colorScheme == .dark ? Color.black : Color.white)
                            .cornerRadius(8)
                            .foregroundColor(.primary)
                            .shadow(color: .black.opacity(0.05), radius: 4)
                            .clearButton($roomCode)
                        
                        TextField("nickname_placeholder", text: $nickname)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .font(.body)
                            .padding()
                            .background(colorScheme == .dark ? Color.black : Color.white)
                            .cornerRadius(8)
                            .foregroundColor(.primary)
                            .shadow(color: .black.opacity(0.05), radius: 4)
                            .clearButton($nickname)
                        
                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.errorRed)
                                .multilineTextAlignment(.center)
                        }
                        
                        let isJoinDisabled = isLoading
                            || roomCode.count != 6
                            || nickname.trimmingCharacters(in: .whitespaces).isEmpty

                        ButtonText(
                            title: isLoading ? "loading_text" : "join_button",
                            action: joinNew,
                            backgroundColor: isJoinDisabled ? .gray : .successGreen,
                            textColor: .white,
                            cornerRadius: 12,
                            size: .big
                        )
                        .disabled(isJoinDisabled)
                    }

                    Spacer(minLength: 0)
                }
                .padding()
                .safeAreaPadding(.bottom)
            }
        }
        .keyboardAdaptive()
    }
}

// MARK: - Helpers & Firestore (Extension)
extension JoinGameView {

    // MARK: - Join flows

    private func joinNew() {
        errorMessage = nil
        roomCode = roomCode.uppercased()

        guard roomCode.count == 6 else {
            errorMessage = String(localized: "invalid_room_code_error", bundle: .main, locale: lang.locale)
            return
        }

        let name = nickname.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            errorMessage = String(localized: "empty_nickname_error", bundle: .main, locale: lang.locale)
            return
        }

        isLoading = true
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(roomCode)

        // 1) Oda var mı?
        roomRef.getDocument { snap, err in
            guard err == nil, let snap = snap, snap.exists else {
                finish(error: String(localized: "room_not_found_error", bundle: .main, locale: lang.locale))
                return
            }

            // 2) Host hazır mı?
            checkHostReady(roomRef: roomRef) { ready in
                guard ready else {
                    finish(error: String(localized: "host_not_ready_error", bundle: .main, locale: lang.locale))
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
                    .setData(playerData, merge: true) { setErr in
                        if let setErr = setErr {
                            let fmt = String(localized: "join_failed_error", bundle: .main, locale: lang.locale)
                            finish(error: String(format: fmt, locale: lang.locale, setErr.localizedDescription))
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
        let upper = code.uppercased()
        let roomRef = db.collection("rooms").document(upper)

        roomRef.getDocument { snap, err in
            guard err == nil, let snap = snap, snap.exists else {
                finish(error: String(localized: "room_not_found_error", bundle: .main, locale: lang.locale))
                return
            }

            checkHostReady(roomRef: roomRef) { ready in
                guard ready else {
                    finish(error: String(localized: "host_not_ready_error", bundle: .main, locale: lang.locale))
                    return
                }

                isLoading = false
                recent.add(upper)
                routeToCurrentState(code: upper)
            }
        }
    }

    private func leaveRoom(code: String) {
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(code)

        roomRef.getDocument { snap, _ in
            guard let data = snap?.data(),
                  let info = data["info"] as? [String: Any],
                  let hostId = info["hostId"] as? String else { return }

            if hostId == deviceId {
                // Host isem: Odayı tamamen sil
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
                    // rol alanı eksik olsa da isim girilmişse yine hazır sayabiliriz
                    completion(true)
                }
            }
        }
    }

    // MARK: - Smart routing (status + role + selection)
    private func routeToCurrentState(code: String) {
        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(code)

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
                self.errorMessage = String.localized(key: "room_info_error", code: lang.code)
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
                    let vm = RoomViewModel(roomCode: code)
                    if !locked.isEmpty {
                        self.router.replace(with: GameSettingsView(vm: vm, roomCode: code, selectedIds: locked))
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

    // MARK: - Error helper
    private func finish(error: String) {
        DispatchQueue.main.async {
            self.errorMessage = error
            self.isLoading = false
        }
    }
}
