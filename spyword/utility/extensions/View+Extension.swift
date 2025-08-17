import SwiftUI

extension View {
    func clearButton(_ text: Binding<String>) -> some View {
        self.overlay(alignment: .trailing) {
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 10)
                        .padding(.vertical, 10) // dokunma alanı
                }
                .accessibilityLabel(Text("clear_text"))
            }
        }
    }
}
