import SwiftUI

struct GameSettingsView: View {
    @ObservedObject var vm: RoomViewModel
    @EnvironmentObject var router: Router
    let roomCode: String
    let selectedIds: [String]

    private let deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString

    private var maxSpyCount: Int {
        max(0, selectedIds.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    vm.setStatus("waiting")
                    router.replace(with: RoomView(roomCode: roomCode))
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
                    Picker("Başlangıç", selection: $vm.mode) {
                        Text("Rastgele kelimeyle başla").tag(GameSettings.WordMode.random)
                        Text("Kendin gir").tag(GameSettings.WordMode.custom)
                    }
                    .pickerStyle(.inline)

                    if vm.mode == .custom {
                        TextField("Kelimeyi yaz", text: $vm.customWord)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .onChange(of: vm.customWord) { _, new in
                                if new.count > 40 { vm.customWord = String(new.prefix(40)) }
                            }
                        Text("Not: Kelimeyi host girerse, host otomatik bilen olur.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Sayısal Ayarlar")) {
                    Stepper(value: $vm.spyCount, in: 0...maxSpyCount) {
                        HStack {
                            Text("Spy sayısı")
                            Spacer()
                            Text("\(vm.spyCount)")
                        }
                    }

                    Stepper(value: $vm.totalRounds, in: 1...10) {
                        HStack {
                            Text("Tur sayısı")
                            Spacer()
                            Text("\(vm.totalRounds)")
                        }
                    }
                }

                Section {
                    Button {
                        let settings = GameSettings(
                            mode: vm.mode,
                            customWord: vm.mode == .custom ? vm.customWord : nil,
                            spyCount: vm.spyCount,
                            totalRounds: vm.totalRounds
                        )
                        vm.startGame(selectedIds: selectedIds, settings: settings)
                        router.replace(with: GameDetailView(roomCode: roomCode))
                    } label: {
                        Text("Başlat")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!canStart)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // güvenlik: sadece host
            if vm.hostId != deviceId {
                router.pop()
            }
            // varsayılan spy sayısı
            vm.spyCount = min(1, maxSpyCount)
        }
    }

    private var canStart: Bool {
        if selectedIds.count < 2 { return false }
        if vm.mode == .custom {
            return !vm.customWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }
}
