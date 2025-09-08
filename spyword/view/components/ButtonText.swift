import SwiftUI

enum ButtonSize {
    case big
    case small
}

struct ButtonText: View {
    private let titleKey: LocalizedStringKey
    let action: () -> Void
    var backgroundColor: Color = .secondaryBlue
    var textColor: Color = .white
    var cornerRadius: CGFloat = 12
    var size: ButtonSize = .big

    init(title: LocalizedStringKey,
         action: @escaping () -> Void,
         backgroundColor: Color = .secondaryBlue,
         textColor: Color = .white,
         cornerRadius: CGFloat = 12,
         size: ButtonSize = .big) {
        self.titleKey = title
        self.action = action
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.cornerRadius = cornerRadius
        self.size = size
    }

    init(verbatim title: String,
         action: @escaping () -> Void,
         backgroundColor: Color = .secondaryBlue,
         textColor: Color = .white,
         cornerRadius: CGFloat = 12,
         size: ButtonSize = .big) {
        self.titleKey = LocalizedStringKey(title)
        self.action = action
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.cornerRadius = cornerRadius
        self.size = size
    }

    var body: some View {
        Button(action: action) {
            Text(titleKey)
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
        case .big:   return UIScreen.main.bounds.width * 0.4
        case .small: return UIScreen.main.bounds.width * 0.2
        }
    }
}
