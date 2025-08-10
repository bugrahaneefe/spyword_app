import SwiftUI

struct SelectPlayersView: View {
    let roomCode: String
    @ObservedObject var vm: RoomViewModel
    @EnvironmentObject var router: Router
    @State private var chosen: Set<String> = []

    private let deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Oyuncu Seç").font(.title3).bold()
                    Text("\(chosen.count) seçili").font(.caption).foregroundColor(.secondary)
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
                        Image(systemName: chosen.contains(p.id) ? "checkmark.circle.fill" : "circle")
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
                    router.navigate(
                        to: RoomView(roomCode: roomCode).withRouter(),
                        type: .modal // veya .push ile de çalışır ama popTo köke döndürür
                    )
                } label: {
                    Text("İptal")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(12)
                }

                Button {
                    // Seçimi kaydet, arranging devam → host ayar ekranına
                    vm.saveSelection(Array(chosen)) { err in
                        if let err = err {
                            print("Save selection error: \(err.localizedDescription)")
                        } else {
                            router.navigate(
                                to: GameSettingsView(vm: vm, roomCode: roomCode, selectedIds: Array(chosen)).withRouter(),
                                type: .push
                            )
                        }
                    }
                } label: {
                    Text("Devam")
                        .frame(maxWidth: .infinity).padding()
                        .background(chosen.count >= 2 ? Color.primaryBlue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(chosen.count < 2)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true) // <— geri butonunu kaldır
        .onAppear {
            vm.beginArranging()
            chosen = Set(vm.players.filter { $0.isSelected == true }.map { $0.id })
        }
        .onChange(of: vm.players) { _, players in
            let currentIds = Set(players.map { $0.id })
            chosen = chosen.intersection(currentIds)
        }
        .onChange(of: vm.hostId) { _, host in
            if host != deviceId { router.pop() }
        }
    }

    // MARK: - Helpers
    private func toggle(_ id: String) {
        if chosen.contains(id) { chosen.remove(id) } else { chosen.insert(id) }
    }
    private func selectAll() { chosen = Set(vm.players.map { $0.id }) }
    private func clearAll() { chosen.removeAll() }
}
