import SwiftUI

extension Font {
    static func poppins(_ weight: Font.Weight, size: CGFloat) -> Font {
        return .custom("Poppins", size: size).weight(weight)
    }
    
    static let h1 = poppins(.bold, size: 32)
    static let h2 = poppins(.semibold, size: 24)
    static let button = poppins(.medium, size: 18)
    static let body = poppins(.regular, size: 16)
    static let caption = poppins(.regular, size: 14)
}
