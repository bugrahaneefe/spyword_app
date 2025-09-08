import SwiftUI

final class LanguageManager: ObservableObject {
    static let supported = ["en", "tr", "de", "fr", "es", "pt", "it"]
    private let storageKey = "app.language"

    @AppStorage("app.language") private var stored: String = ""
    @Published var code: String = "en"

    init() {
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
        stored = newCode
    }
}

extension String {
    static func localized(key: String, code: String, _ args: CVarArg...) -> String {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        let format = NSLocalizedString(key, bundle: bundle, comment: "")
        return String(format: format, locale: Locale(identifier: code), arguments: args)
    }
}
