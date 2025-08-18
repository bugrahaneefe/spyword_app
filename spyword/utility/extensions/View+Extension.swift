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

extension View {
    func slidingPage(
        isPresented: Binding<Bool>,
        text: String,
        image: Image = Image("slideSplash"),
        slideDuration: Double = 0.35,
        holdDuration: Double = 1.0,
        verticalAnchor: CGFloat = 0.68,
        verticalOffset: CGFloat = 0
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                SlidingSplashPage(
                    isPresented: isPresented,
                    text: text,
                    image: image,
                    slideDuration: slideDuration,
                    holdDuration: holdDuration,
                    verticalAnchor: verticalAnchor,
                    verticalOffset: verticalOffset
                )
            }
        }
    }
}
