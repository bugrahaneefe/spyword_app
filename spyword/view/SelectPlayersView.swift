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
                    Text(NSLocalizedString("select_players", comment: "")).font(.title3).bold()
                    Text(String(format: NSLocalizedString("selected_count", comment: ""), vm.chosen.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                StatusBadge(status: "arranging")
                Spacer()
                Menu {
                    Button(NSLocalizedString("select_all", comment: ""), action: selectAll)
                    Button(NSLocalizedString("clear", comment: ""), action: clearAll)
                } label: {
                    Label(NSLocalizedString("options", comment: ""), systemImage: "ellipsis.circle")
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
                            .foregroundStyle((p.id == vm.hostId) ? Color.successGreen : Color.primary)
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
                    router.replace(with: RoomView(roomCode: roomCode))
                } label: {
                    Text(NSLocalizedString("cancel", comment: ""))
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(12)
                }

                Button {
                    vm.saveSelection(Array(vm.chosen)) { err in
                        if let err = err {
                            print("Save selection error: \(err.localizedDescription)")
                        } else {
                            router.replace(
                                with: GameSettingsView(
                                    vm: vm,
                                    roomCode: roomCode,
                                    selectedIds: Array(vm.chosen)
                                )
                            )
                        }
                    }
                } label: {
                    Text(NSLocalizedString("continue", comment: ""))
                        .frame(maxWidth: .infinity).padding()
                        .background(vm.chosen.count >= 2 ? Color.primaryBlue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(vm.chosen.count < 2)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            vm.beginArranging()
            vm.chosen = Set(vm.players.filter { $0.isSelected == true }.map { $0.id })
            if let host = vm.hostId {
                vm.chosen.insert(host)
            }
        }
        .onChange(of: vm.players) { _, players in
            let currentIds = Set(players.map { $0.id })
            vm.chosen = vm.chosen.intersection(currentIds)
            if let host = vm.hostId {
                vm.chosen.insert(host)
            }
        }
        .onChange(of: vm.hostId) { _, host in
            if host != deviceId { router.pop() }
        }
    }

    // MARK: - Helpers
    private func toggle(_ id: String) {
        if id == vm.hostId { return }
        if vm.chosen.contains(id) {
            vm.chosen.remove(id)
        } else {
            vm.chosen.insert(id)
        }
    }

    private func selectAll() {
        vm.chosen = Set(vm.players.map { $0.id })
        if let host = vm.hostId {
            vm.chosen.insert(host)
        }
    }

    private func clearAll() {
        vm.chosen.removeAll()
        if let host = vm.hostId {
            vm.chosen.insert(host)
        }
    }
}
