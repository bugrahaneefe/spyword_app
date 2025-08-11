import SwiftUI

final class LanguageManager: ObservableObject {
    static let supported = ["en", "tr"]
    private let storageKey = "app.language"

    @AppStorage("app.language") private var stored: String = ""  // ok to keep
    @Published var code: String = "en"  // give a temp default so it's initialized

    init() {
        // Read raw value without touching `self.stored` yet
        let storedValue = UserDefaults.standard.string(forKey: storageKey) ?? ""
        let initial: String

        if !storedValue.isEmpty, Self.supported.contains(storedValue) {
            initial = storedValue
        } else {
            let device = Locale.preferredLanguages.first
                .map { String($0.prefix(2)) } ?? "en"
            initial = Self.supported.contains(device) ? device : "en"
            UserDefaults.standard.set(initial, forKey: storageKey)
        }

        self.code = initial
    }

    var locale: Locale { Locale(identifier: code) }

    func set(_ newCode: String) {
        guard Self.supported.contains(newCode) else { return }
        code = newCode
        stored = newCode   // safe here
    }
}
