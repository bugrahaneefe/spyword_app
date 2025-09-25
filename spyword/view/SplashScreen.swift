import SwiftUI

private enum Constant {
    static let splashImage = Image("splashScreen")
}

struct SplashScreen: View {
    @EnvironmentObject var router: Router
    @State private var showButton = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Constant.splashImage
                .resizable()
                .ignoresSafeArea()
            
            VStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            .padding(.bottom, 96)
        }
        .onAppear {
            let delay = Double.random(in: 0.5...1.75)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.5)) {
                    router.replace(with: MainView())
                }
            }
        }
    }
}
