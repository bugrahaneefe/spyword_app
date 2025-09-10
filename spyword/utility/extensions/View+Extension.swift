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

extension View {
    func swipeBack<Destination: View>(
        to destination: Destination,
        by router: Router,
        threshold: CGFloat = 60,
        edgeWidth: CGFloat = 32
    ) -> some View {
        self.gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let isHorizontal = abs(dx) > abs(dy)
                    
                    let startedFromLeftEdge = value.startLocation.x < edgeWidth
                    let passedThreshold = dx > threshold
                    
                    if isHorizontal && startedFromLeftEdge && passedThreshold {
                        router.replace(with: destination)
                    }
                }
        )
    }
}
