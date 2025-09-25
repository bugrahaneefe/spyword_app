import SwiftUI

struct LoadingView: View {
    @State var isLoading: Bool
    
    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryBlue))
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 8)
            }
        }
    }
}
