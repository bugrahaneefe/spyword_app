import SwiftUI

struct ConfirmPopup: View {
    @Binding var isPresented: Bool

    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let isDestructive: Bool
    let onConfirm: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var cardBG: Color { scheme == .dark ? .black : .white }

    var body: some View {
        if isPresented {
            ZStack {
                // Dimmed backdrop
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { withAnimation { isPresented = false } }

                // Card
                VStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 10) {
                        Button {
                            withAnimation { isPresented = false }
                        } label: {
                            Text(cancelTitle)
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .foregroundColor(Color.backgroundDark)
                                .padding(.vertical, 12)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(10)
                        }

                        Button {
                            withAnimation { isPresented = false }
                            onConfirm()
                        } label: {
                            Text(confirmTitle)
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isDestructive ? Color.red : Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.top, 4)
                }
                .padding(18)
                .frame(maxWidth: 360)
                .background(cardBG)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 24)
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                        removal: .opacity))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isPresented)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}

// Convenience modifier
extension View {
    func confirmPopup(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        cancelTitle: String = "Cancel",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) -> some View {
        overlay {
            ConfirmPopup(
                isPresented: isPresented,
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                cancelTitle: cancelTitle,
                isDestructive: isDestructive,
                onConfirm: onConfirm
            )
        }
    }
}
