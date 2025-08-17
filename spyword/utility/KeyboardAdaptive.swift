import SwiftUI

extension View {
    func keyboardAdaptive() -> some View {
        self
            .ignoresSafeArea(.keyboard)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            }
    }
}
