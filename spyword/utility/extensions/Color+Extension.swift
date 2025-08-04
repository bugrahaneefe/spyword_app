import SwiftUI

extension Color {
    // Primary Blues
    static let primaryBlue = Color(hex: "#1A4FFF")
    static let secondaryBlue = Color(hex: "#255AFD")
    
    // Neutrals & Backgrounds
    static let backgroundLight = Color(hex: "#F0F2F6")
    static let backgroundDark = Color(hex: "#121212")
    static let white = Color.white
    static let black = Color(hex: "#222222")
    
    // Status
    static let successGreen = Color(hex: "#00B894")
    static let errorRed = Color(hex: "#D63031")
    static let warningYellow = Color(hex: "#F6DC3B")
}

// HEX initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64

        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255,
                           (int >> 8) * 17,
                           (int >> 4 & 0xF) * 17,
                           (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255,
                           int >> 16,
                           int >> 8 & 0xFF,
                           int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24,
                           int >> 16 & 0xFF,
                           int >> 8 & 0xFF,
                           int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
