import SwiftUI

private enum Constant {
    static let splashImage = Image("splashScreen")
    static let startString = "Start"
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
                    ButtonText(title: Constant.startString) {
                        router.navigate(to: MainView().withRouter(), type: .modal)
                    }
                    .transition(.opacity)
                }
                .padding(.bottom, 96)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showButton = true
                }
            }
        }
    }
}
