import Foundation

/// Manages the list of room codes the user has previously joined
final class RecentRoomsManager: ObservableObject {
    @Published private(set) var codes: [String] = []
    private let userDefaultsKey = "recentRooms"

    static let shared = RecentRoomsManager()

    private init() {
        codes = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }

    /// Add a code to the front of the list (max 10 entries)
    func add(_ code: String) {
        var arr = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
        // move to front if exists
        arr.removeAll { $0 == code }
        arr.insert(code, at: 0)
        if arr.count > 10 { arr = Array(arr.prefix(10)) }
        UserDefaults.standard.set(arr, forKey: userDefaultsKey)
        codes = arr
    }
}
