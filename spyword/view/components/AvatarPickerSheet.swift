import SwiftUI

struct AvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var avatar: AvatarManager

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AvatarManager.allNames, id: \.self) { name in
                        Button {
                            avatar.selectedName = name
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        } label: {
                            Image(name)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    Circle().stroke(
                                        avatar.selectedName == name
                                        ? Color.primary : Color.clear, lineWidth: 2
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Choose Avatar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
