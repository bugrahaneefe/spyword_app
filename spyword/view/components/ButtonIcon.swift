import SwiftUI

struct ButtonIcon: View {
    let iconName: String
    let action: () -> Void
    var backgroundColor: Color = .secondaryBlue
    var iconColor: Color = .white
    var cornerRadius: CGFloat = 12
    var size: ButtonSize = .small
    var systemImage: Bool = true

    var body: some View {
        Button(action: action) {
            Group {
                if systemImage {
                    Image(systemName: iconName)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                }
            }
            .foregroundColor(iconColor)
            .frame(width: 24, height: 24)
            .padding()
            .frame(width: calculatedWidth)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.6), radius: 6)
        }
    }

    private var calculatedWidth: CGFloat {
        switch size {
        case .big:
            return UIScreen.main.bounds.width * 0.25
        case .small:
            return UIScreen.main.bounds.width * 0.1
        case .justCaption:
            return UIScreen.main.bounds.width * 0.075
        }
    }
}
