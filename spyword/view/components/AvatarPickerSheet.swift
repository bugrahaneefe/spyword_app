import SwiftUI

struct AvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var avatar: AvatarManager

    private static let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 4
    )

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { content }
            } else {
                NavigationView { content }
            }
        }
        .navigationTitle(Text("choose_avatar"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Split out the heavy layout
    private var content: some View {
        ScrollView {
            LazyVGrid(columns: Self.columns, spacing: 12) {
                ForEach(AvatarManager.allNames, id: \.self) { name in
                    AvatarCell(
                        name: name,
                        isSelected: avatar.selectedAvatar == name
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        avatar.selectAvatar(name)
                        dismiss()
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Small, compiler-friendly cell
private struct AvatarCell: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color(.secondarySystemBackground))
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
            }
            .frame(width: 72, height: 72)
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
