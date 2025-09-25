import SwiftUI

struct SelectPlayersView: View {
    // MARK: - Inputs
    let roomCode: String
    @ObservedObject var vm: RoomViewModel

    // MARK: - Env
    @EnvironmentObject var router: Router
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Device
    private let deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("select_players").font(.title3).bold()
                    Text(String.localized(key: "selected_count", code: lang.code, vm.chosen.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                StatusBadge(status: "arranging")
                
                Spacer()
                
                Menu {
                    Button("select_all", action: selectAll)
                    Button("clear", action: clearAll)
                } label: {
                    Label("options", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
            }
            .padding()
            .background(colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
            
            DescriptionText(inputKey: "select_players_description")
            
            Divider()

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
                    Text("cancel")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(Color.white)
                        .background(Color.primaryBlue)
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
                    Text("continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vm.chosen.count >= 2 ? Color.successGreen : Color.gray)
                        .foregroundColor(Color.white)
                        .cornerRadius(12)
                }
                .disabled(vm.chosen.count < 2)
            }
            .padding()
        }
        .swipeBack(to: RoomView(roomCode: roomCode), by: router)
        .background(colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            setupInitialSelection()
        }
        .onChange(of: vm.players) { _, players in
            syncChosen(with: players)
        }
        .onChange(of: vm.hostId) { _, host in
            if host != deviceId { router.pop() }
        }
    }
}

// MARK: - Helpers (Extension)
extension SelectPlayersView {
    private func toggle(_ id: String) {
        guard id != vm.hostId else { return }
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

    private func setupInitialSelection() {
        vm.beginArranging()
        vm.chosen = Set(vm.players.filter { $0.isSelected == true }.map { $0.id })
        if let host = vm.hostId {
            vm.chosen.insert(host)
        }
    }

    private func syncChosen(with players: [Player]) {
        let currentIds = Set(players.map { $0.id })
        vm.chosen = vm.chosen.intersection(currentIds)
        if let host = vm.hostId {
            vm.chosen.insert(host)
        }
    }
}
