import SwiftUI

struct Player: Identifiable, Equatable {
    let id: String
    let name: String
    let role: String?
    var isEliminated: Bool?
    var isSelected: Bool?
    let avatarName: String?
}
