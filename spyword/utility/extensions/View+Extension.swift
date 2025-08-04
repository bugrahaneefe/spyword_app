import SwiftUI

extension View {
    func withRouter() -> some View {
        self.modifier(WithRouter())
    }
}
