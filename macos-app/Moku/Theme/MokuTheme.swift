import SwiftUI

/// Moku design system — warm, bookish aesthetic matching the Flutter app
enum MokuTheme {

    // MARK: - Brand Colors
    static let violet = Color(red: 0.42, green: 0.31, blue: 1.0)        // #6B4EFF
    static let coral = Color(red: 1.0, green: 0.54, blue: 0.40)         // #FF8A65
    static let warmCream = Color(red: 0.98, green: 0.97, blue: 0.95)    // #FAF7F2
    static let paperWhite = Color(red: 1.0, green: 0.98, blue: 0.97)    // #FFFBF7
    static let inkDark = Color(red: 0.11, green: 0.10, blue: 0.09)      // #1C1917

    // MARK: - Dark Mode
    static let nightSurface = Color(red: 0.10, green: 0.09, blue: 0.09) // #1A1816
    static let nightCard = Color(red: 0.15, green: 0.13, blue: 0.13)    // #252220
    static let warmLight = Color(red: 0.91, green: 0.89, blue: 0.87)    // #E8E4DF

    // MARK: - Reader Themes
    static let sepiaBg = Color(red: 0.96, green: 0.93, blue: 0.85)      // #F4ECD8
    static let sepiaText = Color(red: 0.36, green: 0.27, blue: 0.21)    // #5B4636

    // MARK: - Typography
    static let serifFont = "Georgia"
    static let serifFontAlt = "Palatino"

    // MARK: - Spacing
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20

    // MARK: - Shadows
    static func bookShadow(_ scheme: ColorScheme) -> some View {
        EmptyView() // Use .shadow modifiers directly
    }

    // MARK: - Procedural Cover Color
    static func coverColor(for title: String) -> Color {
        let hash = abs(title.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.35, brightness: 0.55)
    }

    static func coverAccentColor(for title: String) -> Color {
        let hash = abs(title.hashValue)
        let hue = Double((hash + 120) % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.7)
    }
}

// MARK: - View Extension for warm background

extension View {
    func warmBackground(_ scheme: ColorScheme) -> some View {
        self.background(scheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
    }
}
