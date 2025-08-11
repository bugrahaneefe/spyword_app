import SwiftUI

struct SelectPlayersView: View {
    let roomCode: String
    @ObservedObject var vm: RoomViewModel
    @EnvironmentObject var router: Router

    private let deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Oyuncu Seç").font(.title3).bold()
                    Text("\(vm.chosen.count) seçili").font(.caption).foregroundColor(.secondary)
                }
                StatusBadge(status: "arranging")
                Spacer()
                Menu {
                    Button("Hepsini Seç", action: selectAll)
                    Button("Temizle", action: clearAll)
                } label: {
                    Label("Seçenekler", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
            }
            .padding()
            Divider()

            // Players list (hücre tamamı tıklanır)
            List {
                ForEach(vm.players) { p in
                    HStack {
                        Text(p.name)
                        Spacer()
                        Image(systemName: vm.chosen.contains(p.id) ? "checkmark.circle.fill" : "circle")
                            .imageScale(.large)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(p.id) }
                }
            }
            .listStyle(.insetGrouped)

            // Bottom actions
            HStack(spacing: 12) {
                Button {
                    vm.setStatus("waiting")
                    // Host, RoomView'a geri dönsün
                    router.replace(with: RoomView(roomCode: roomCode))
                } label: {
                    Text("İptal")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(12)
                }

                Button {
                    // Seçimi kaydet, arranging devam → host ayar ekranına
                    vm.saveSelection(Array(vm.chosen)) { err in
                        if let err = err {
                            print("Save selection error: \(err.localizedDescription)")
                        } else {
                            router.replace(with: GameSettingsView(vm: vm, roomCode: roomCode, selectedIds: Array(vm.chosen)))
                        }
                    }
                } label: {
                    Text("Devam")
                        .frame(maxWidth: .infinity).padding()
                        .background(vm.chosen.count >= 2 ? Color.primaryBlue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(vm.chosen.count < 2)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true) // <— geri butonunu kaldır
        .onAppear {
            vm.beginArranging()
            vm.chosen = Set(vm.players.filter { $0.isSelected == true }.map { $0.id })
        }
        .onChange(of: vm.players) { _, players in
            let currentIds = Set(players.map { $0.id })
            vm.chosen = vm.chosen.intersection(currentIds)
        }
        .onChange(of: vm.hostId) { _, host in
            if host != deviceId { router.pop() }
        }
    }

    // MARK: - Helpers
    private func toggle(_ id: String) {
        if vm.chosen.contains(id) { vm.chosen.remove(id) } else { vm.chosen.insert(id) }
    }
    private func selectAll() { vm.chosen = Set(vm.players.map { $0.id }) }
    private func clearAll() { vm.chosen.removeAll() }
}
