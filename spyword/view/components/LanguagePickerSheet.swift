import SwiftUI

struct LanguagePickerSheet: View {
    let selected: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isDragging = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    languageButton(code: "tr")
                    languageButton(code: "en")
                    languageButton(code: "de")
                    languageButton(code: "fr")
                    languageButton(code: "es")
                    languageButton(code: "pt")
                    languageButton(code: "it")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { _ in
                        if !isDragging { isDragging = true }
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isDragging = false
                        }
                    }
            )
            .navigationTitle(Text("language_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers

    private func languageButton(code: String) -> some View {
        let label = "\(flag(for: code)) \(endonym(for: code))" + (code == selected ? "  ✓" : "")

        return ButtonText(title: LocalizedStringKey(label)) {
            onSelect(code)
            dismiss()
        }
    }

    private func endonym(for code: String) -> String {
        Locale(identifier: code)
            .localizedString(forLanguageCode: code)?
            .capitalized(with: Locale(identifier: code))
        ?? code.uppercased()
    }

    private func flag(for code: String) -> String {
        switch code.lowercased() {
        case "tr": return "\u{1F1F9}\u{1F1F7}" // 🇹🇷
        case "en": return "\u{1F1EC}\u{1F1E7}" // 🇬🇧
        case "de": return "\u{1F1E9}\u{1F1EA}" // 🇩🇪
        case "fr": return "\u{1F1EB}\u{1F1F7}" // 🇫🇷
        case "es": return "\u{1F1EA}\u{1F1F8}" // 🇪🇸
        case "pt": return "\u{1F1F5}\u{1F1F9}" // 🇵🇹
        case "it": return "\u{1F1EE}\u{1F1F9}" // 🇮🇹
        default:   return "\u{1F310}"          // 🌐
        }
    }
}
