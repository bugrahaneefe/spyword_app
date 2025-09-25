import SwiftUI

final class AvatarManager: ObservableObject {
    static let shared = AvatarManager()

    private let key = "user.avatarName"
    static let allNames: [String] = (1...10).map { "\($0)" }

    @Published var selectedName: String {
        didSet { UserDefaults.standard.set(selectedName, forKey: key) }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: key),
           AvatarManager.allNames.contains(saved) {
            self.selectedName = saved
        } else {
            let random = AvatarManager.allNames.randomElement()!
            self.selectedName = random
            UserDefaults.standard.set(random, forKey: key)
        }
    }

    var image: Image {
        Image(selectedName)
    }
}
