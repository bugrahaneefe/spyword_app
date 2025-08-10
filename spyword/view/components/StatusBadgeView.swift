import SwiftUI

struct StatusBadge: View {
    let status: String

    private var label: String {
        switch status.lowercased() {
        case "waiting": return "Waiting"
        case "arranging": return "Arranging"
        case "started": return "Started"
        case "the game": return "In Game"
        default: return status.capitalized
        }
    }

    private var color: Color {
        switch status.lowercased() {
        case "waiting": return .gray
        case "arranging": return .orange
        case "started": return .blue
        case "the game": return .green
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
            Text(label).font(.caption).bold()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundColor(.white)
        .background(color)
        .clipShape(Capsule())
        .accessibilityLabel("Room status: \(label)")
    }
}

