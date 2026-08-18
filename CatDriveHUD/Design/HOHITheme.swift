import SwiftUI

enum HOHITheme {
    static let ink = Color(red: 0.09, green: 0.10, blue: 0.16)
    static let muted = Color(red: 0.45, green: 0.47, blue: 0.56)
    static let purple = Color(red: 0.34, green: 0.28, blue: 0.96)
    static let purpleSoft = Color(red: 0.61, green: 0.51, blue: 0.98)
    static let pink = Color(red: 0.98, green: 0.20, blue: 0.48)
    static let background = Color(red: 0.965, green: 0.965, blue: 0.995)
    static let card = Color.white.opacity(0.94)
    static let navNavy = Color(red: 0.025, green: 0.055, blue: 0.095)
    static let navCard = Color(red: 0.065, green: 0.105, blue: 0.16)

    static let primaryGradient = LinearGradient(
        colors: [purple, purpleSoft],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension Font {
    static func hohi(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    func hohiCard(radius: CGFloat = 24) -> some View {
        self
            .background(HOHITheme.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.065), radius: 20, y: 8)
    }
}
