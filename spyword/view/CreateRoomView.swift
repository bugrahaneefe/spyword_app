import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct CreateRoomView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var avatar: AvatarManager
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var recent = RecentRoomsManager.shared

    @State private var roomCode: String = ""
    @State private var hostName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCopied = false
    
    private let deviceId = UserDefaults.standard
        .string(forKey: "deviceId") ?? UUID().uuidString
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
                .ignoresSafeArea()
                .onAppear {
                    hostName = avatar.displayName
                }
            
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
                
                DescriptionText(inputKey: "create_room_description")
                    .background(colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)

                Divider()
                
                VStack(spacing: 32) {
                    Text("preparing_room")
                        .font(.h2)
                        .foregroundColor(.primary)
                        .padding()
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                    } else if !roomCode.isEmpty {
                        ZStack(alignment: .topTrailing) {
                            Text(roomCode)
                                .font(.h1)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(colorScheme == .dark ? Color.black : Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                                .foregroundColor(.primary)
                            
                            Button(action: copyCode) {
                                if showCopied {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .padding(8)
                                } else {
                                    Text("copy")
                                        .font(.caption)
                                        .foregroundColor(.primaryBlue)
                                        .padding(8)
                                }
                            }
                            .accessibilityLabel(Text("copy"))
                        }
                        
                        HStack(spacing: 10) {
                            avatar.image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                                .shadow(radius: 1)

                            TextField(
                                String.localized(key: "your_name", code: lang.code),
                                text: $hostName
                            )
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .clearButton($hostName)
                        }
                        .font(.body)
                        .padding()
                        .background(colorScheme == .dark ? Color.black : Color.white)
                        .cornerRadius(8)
                        .foregroundColor(.primary)
                        .shadow(color: .black.opacity(0.05), radius: 4)
                        
                        let isFinalizeDisabled = hostName.trimmingCharacters(in: .whitespaces).isEmpty

                        ButtonText(
                            title: "next",
                            backgroundColor: isFinalizeDisabled ? .gray : .successGreen,
                            textColor: .white,
                            cornerRadius: 12,
                            size: .big,
                            action: finalizeRoom
                        )
                        .disabled(isFinalizeDisabled)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.errorRed)
                    }
                    
                    Spacer()
                }
                .padding()
                .safeAreaPadding(.bottom)
            }
            .overlay {
                LoadingView(isLoading: isLoading)
            }
        }
        .swipeBack(to: MainView(), by: router)
        .onAppear{ createRoom() }
        .keyboardAdaptive()
    }
}

// MARK: Helpers
extension CreateRoomView {
    
    // MARK: - Firestore
    private func createRoom() {
        isLoading = true
        errorMessage = nil
        
        let code = randomAlphaNumeric(length: 6)
        let db = Firestore.firestore()
        let roomDoc = db.collection("rooms").document(code)
        let infoData: [String: Any] = [
            "hostId": deviceId,
            "status": "waiting",
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        roomDoc.setData(["info": infoData], merge: true) { error in
            isLoading = false
            if let err = error {
                let fmt = String.localized(key: "room_creation_failed", code: lang.code)
                errorMessage = String(format: fmt, locale: lang.locale, err.localizedDescription)
            } else {
                roomCode = code
            }
        }
    }
    
    private func finalizeRoom() {
        guard !hostName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        let db = Firestore.firestore()
        let playerData: [String: Any] = [
            "name": hostName.trimmingCharacters(in: .whitespaces),
            "role": "host",
            "isEliminated": false,
            "isSelected": false,
            "joinedAt": FieldValue.serverTimestamp()
        ]
        
        Task { @MainActor in
            let root = UIApplication.shared.topMostViewController()
            do {
                try await AdsManager.shared.showInterstitial(from: root, chance: 90)
            } catch {
                print("Interstitial error: \(error)")
            }
        }
        
        db.collection("rooms")
            .document(roomCode)
            .collection("players")
            .document(deviceId)
            .setData(playerData) { error in
                isLoading = false
                if let err = error {
                    let fmt = String(localized: "name_add_failed", bundle: .main, locale: lang.locale)
                    errorMessage = String(format: fmt, locale: lang.locale, err.localizedDescription)
                } else {
                    recent.add(roomCode)
                    router.replace(with: RoomView(roomCode: roomCode))
                }
            }
    }
    
    private func copyCode() {
        UIPasteboard.general.string = roomCode
        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showCopied = false
            }
        }
    }
    
    private func randomAlphaNumeric(length: Int) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }
}
