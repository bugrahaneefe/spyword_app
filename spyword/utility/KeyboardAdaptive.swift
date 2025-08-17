import SwiftUI

extension View {
    func keyboardAdaptive() -> some View {
        self
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            }
    }
}

