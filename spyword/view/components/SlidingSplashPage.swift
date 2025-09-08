import SwiftUI

private enum Constant {
    static let slideSplash = Image("slideSplash")
}

struct SlidingSplashPage: View {
    @Binding var isPresented: Bool
    let text: String
    var image: Image = Constant.slideSplash
    var slideDuration: Double = 0.6
    var holdDuration: Double = 2.5
    var verticalAnchor: CGFloat = 0.6
    var verticalOffset: CGFloat = 0

    @State private var phase: Phase = .offRight
    private enum Phase { case offRight, on, offLeft }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                image
                    .resizable()
                    .scaledToFill()
                    .clipped()

                Text(text)
                    .font(.h1).bold().italic()
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .shadow(radius: 8)
                    .frame(width: geo.size.width - 48)
                    .fixedSize(horizontal: false, vertical: true)
                    .position(
                        x: geo.size.width / 2,
                        y: (geo.size.height * verticalAnchor) + verticalOffset
                    )
            }
            .contentShape(Rectangle())
            .ignoresSafeArea(.all)
            .offset(x: offset(for: phase, width: geo.size.width))
            .onAppear { animate() }
            .allowsHitTesting(false)
            .zIndex(1000)
        }
    }

    private func offset(for phase: Phase, width: CGFloat) -> CGFloat {
        switch phase {
        case .offRight: return width
        case .on:       return 0
        case .offLeft:  return -width
        }
    }

    private var enterAnimation: Animation {
        .timingCurve(0.15, 0.85, 0.35, 1.0, duration: slideDuration)
    }
    
//    private var exitAnimation: Animation {
//        .timingCurve(0.15, 0.85, 0.35, 1.0, duration: slideDuration)
//    }

    private func animate() {
        withAnimation(enterAnimation) { phase = .on }
        DispatchQueue.main.asyncAfter(deadline: .now() + slideDuration + holdDuration) {
//            withAnimation(exitAnimation) { phase = .offLeft }
            DispatchQueue.main.asyncAfter(deadline: .now() + slideDuration) {
                isPresented = false
            }
        }
    }
}
