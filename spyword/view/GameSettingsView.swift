import SwiftUI

struct GameSettingsView: View {
    @ObservedObject var vm: RoomViewModel
    @EnvironmentObject var router: Router
    let roomCode: String
    let selectedIds: [String]        // SelectPlayersView'den gelir

    @State private var mode: GameSettings.WordMode = .random
    @State private var customWord: String = ""
    @State private var spyCount: Int = 1
    @State private var totalRounds: Int = 3

    private let deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString

    private var maxSpyCount: Int {
        max(0, selectedIds.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom top bar (geri = waiting + RoomView)
            HStack {
                Button {
                    vm.setStatus("waiting")
                    router.navigate(
                        to: RoomView(roomCode: roomCode).withRouter(),
                        type: .push
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Odaya Dön")
                    }
                    .font(.body)
                }

                Spacer()

                Text("Oyun Ayarları").font(.title3).bold()

                Spacer()

                StatusBadge(status: "arranging")
            }
            .padding()
            Divider()

            Form {
                Section(header: Text("Kelime")) {
                    Picker("Başlangıç", selection: $mode) {
                        Text("Rastgele kelimeyle başla").tag(GameSettings.WordMode.random)
                        Text("Kendin gir").tag(GameSettings.WordMode.custom)
                    }
                    .pickerStyle(.inline)

                    if mode == .custom {
                        TextField("Kelimeyi yaz", text: $customWord)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .onChange(of: customWord) { _, new in
                                if new.count > 40 { customWord = String(new.prefix(40)) }
                            }
                        Text("Not: Kelimeyi host girerse, host otomatik bilen olur.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Sayısal Ayarlar")) {
                    Stepper(value: $spyCount, in: 0...maxSpyCount) {
                        HStack {
                            Text("Spy sayısı")
                            Spacer()
                            Text("\(spyCount)")
                        }
                    }

                    Stepper(value: $totalRounds, in: 1...10) {
                        HStack {
                            Text("Tur sayısı")
                            Spacer()
                            Text("\(totalRounds)")
                        }
                    }
                }

                Section {
                    Button {
                        let settings = GameSettings(
                            mode: mode,
                            customWord: mode == .custom ? customWord : nil,
                            spyCount: spyCount,
                            totalRounds: totalRounds
                        )
                        vm.startGame(selectedIds: selectedIds, settings: settings)
                        router.pop() // oyun başlayınca RoomView zaten GameDetail'e yönlendiriyor
                    } label: {
                        Text("Başlat")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!canStart)
                }
            }
        }
        .navigationBarBackButtonHidden(true) // sistem geri butonu kapalı
        .onAppear {
            // güvenlik: sadece host
            if vm.hostId != deviceId {
                router.pop()
            }
            // varsayılan spy sayısı
            spyCount = min(1, maxSpyCount)
        }
    }

    private var canStart: Bool {
        if selectedIds.count < 2 { return false }
        if mode == .custom {
            return !customWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }
}
