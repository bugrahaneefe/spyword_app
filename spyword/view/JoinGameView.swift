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
                    }
                }
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

    private func joinNew() {
        errorMessage = nil
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

        // 1) verify room exists
        roomRef.getDocument { snap, err in
            guard err == nil, let snap = snap, snap.exists else {
                finish(error: "Oda bulunamadı veya geçerli değil.")
                return
            }

            // 2) check players subcol for a host
            roomRef.collection("players")
                .whereField("role", isEqualTo: "host")
                .getDocuments { hostSnap, hostErr in
                    guard hostErr == nil, let docs = hostSnap?.documents,
                          !docs.isEmpty else {
                        finish(error: "Ev sahibinin ismini girip 'İleri' basmasını bekleyin.")
                        return
                    }

                    // 3) now write this player
                    let playerData: [String: Any] = [
                        "name": name,
                        "role": NSNull(),
                        "isEliminated": false,
                        "isSelected": false,
                        "joinedAt": FieldValue.serverTimestamp()
                    ]
                    roomRef.collection("players")
                        .document(deviceId)
                        .setData(playerData) { err in
                            if let err = err {
                                finish(error: "Katılım başarısız: \(err.localizedDescription)")
                            } else {
                                isLoading = false
                                recent.add(roomCode)
                                router.navigate(
                                    to: RoomView(roomCode: roomCode).withRouter(),
                                    type: .push
                                )
                            }
                        }
                }
        }
    }

    private func rejoin(_ code: String) {
        errorMessage = nil
        isLoading = true

        let db = Firestore.firestore()
        let roomRef = db.collection("rooms").document(code)

        // verify room exists
        roomRef.getDocument { snap, err in
            guard err == nil, let snap = snap, snap.exists else {
                finish(error: "Oda bulunamadı veya geçerli değil.")
                return
            }

            // check host ready
            roomRef.collection("players")
                .whereField("role", isEqualTo: "host")
                .getDocuments { hostSnap, hostErr in
                    guard hostErr == nil, let docs = hostSnap?.documents,
                          !docs.isEmpty else {
                        finish(error: "Ev sahibinin ismini girip 'İleri' basmasını bekleyin.")
                        return
                    }

                    isLoading = false
                    recent.add(code)
                    router.navigate(
                        to: RoomView(roomCode: code).withRouter(),
                        type: .push
                    )
                }
        }
    }


    private func finish(error: String) {
        DispatchQueue.main.async {
            self.errorMessage = error
            self.isLoading = false
        }
    }
}
