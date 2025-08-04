import SwiftUI

enum ButtonSize {
    case big     // Half screen
    case small   // Quarter screen
}

struct ButtonText: View {
    let title: String
    let action: () -> Void
    var backgroundColor: Color = .secondaryBlue
    var textColor: Color = .white
    var cornerRadius: CGFloat = 12
    var size: ButtonSize = .big
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.button)
                .foregroundColor(textColor)
                .frame(width: calculatedWidth)
                .padding()
                .background(backgroundColor)
                .cornerRadius(cornerRadius)
                .shadow(color: .black.opacity(0.6), radius: 6)
        }
    }
    
    private var calculatedWidth: CGFloat {
        switch size {
        case .big:
            return UIScreen.main.bounds.width * 0.4
        case .small:
            return UIScreen.main.bounds.width * 0.2
        }
    }
}
