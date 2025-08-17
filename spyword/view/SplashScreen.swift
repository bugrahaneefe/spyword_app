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

            if showButton {
                VStack {
                    Spacer()
                    ButtonText(title: "start") {
                        router.replace(with: MainView())
                    }
                    .transition(.opacity)
                }
                .padding(.bottom, 96)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.5)) { showButton = true }
            }
        }
    }
}
