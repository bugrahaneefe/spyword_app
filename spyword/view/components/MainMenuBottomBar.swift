import SwiftUI

struct MainMenuBottomBar: View {
    @EnvironmentObject var avatar: AvatarManager
    @Environment(\.colorScheme) var colorScheme

    var onLanguage: () -> Void
    var onHowTo:    () -> Void
    var onPrivacy:  () -> Void
    var onAvatar:   () -> Void

    @State private var showNameSheet = false

    var body: some View {
        HStack(spacing: 20) {
            ButtonIcon(iconName: "globe", action: onLanguage, size: .small)
            ButtonIcon(iconName: "questionmark.circle", action: onHowTo, size: .small)
            ButtonIcon(iconName: "lock.shield", action: onPrivacy, size: .small)

            Spacer()

            VStack(spacing: 6) {
                Button(action: onAvatar) {
                    avatar.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1))
                        .shadow(radius: 3)
                }
                .buttonStyle(.plain)

                Button {
                    showNameSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Text(avatar.displayName.isEmpty ? "Your name" : avatar.displayName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "pencil")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(alignment: .center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.primaryBlue.opacity(0.24))
                    )
                    .overlay(
                        Capsule().stroke(Color.primaryBlue.opacity(0.48), lineWidth: 0.8)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .offset(y: -44)
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 8, y: -2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .sheet(isPresented: $showNameSheet) {
            NameEditSheet(currentName: avatar.displayName) { newName in
                avatar.updateName(newName)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}
