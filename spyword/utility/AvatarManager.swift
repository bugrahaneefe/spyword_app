import SwiftUI
import Combine

final class AvatarManager: ObservableObject {
    static let allNames = (1...10).map { "\($0)" }
    @Published var selectedAvatar: String
    @Published var displayName: String

    let availableAvatars: [String] = (1...10).map { "\($0)" }
    private let avatarKey = "avatar.selected"
    private let nameKey   = "avatar.displayName"
    private let maxNameLen = 20

    init() {
        let ud = UserDefaults.standard

        if let saved = ud.string(forKey: avatarKey), !saved.isEmpty {
            self.selectedAvatar = saved
        } else {
            self.selectedAvatar = availableAvatars.randomElement() ?? "1"
        }

        if let saved = ud.string(forKey: nameKey),
           !saved.trimmingCharacters(in: .whitespaces).isEmpty {
            self.displayName = saved
        } else {
            self.displayName = AvatarManager.randomName()
        }

        if ud.string(forKey: avatarKey) == nil {
            ud.set(self.selectedAvatar, forKey: avatarKey)
        }
        if ud.string(forKey: nameKey) == nil {
            ud.set(self.displayName, forKey: nameKey)
        }
    }

    var image: Image { Image(selectedAvatar) }

    func selectAvatar(_ name: String) {
        guard availableAvatars.contains(name) else { return }
        selectedAvatar = name
        UserDefaults.standard.set(name, forKey: avatarKey)
    }

    func updateName(_ new: String) {
        var trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > maxNameLen { trimmed = String(trimmed.prefix(maxNameLen)) }
        if trimmed.isEmpty { trimmed = AvatarManager.randomName() }
        displayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: nameKey)
    }

    private static func randomName() -> String {
        "Player \(Int.random(in: 1000...9999))"
    }
}
