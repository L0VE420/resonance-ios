import SwiftUI

enum ResonanceTheme {
    static let accent = Color(red: 0.37, green: 0.51, blue: 0.93)
    static let secondaryAccent = Color(red: 0.65, green: 0.36, blue: 0.94)
    static let artworkPlaceholder = LinearGradient(
        colors: [accent.opacity(0.88), secondaryAccent.opacity(0.78)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let cornerRadius: CGFloat = 18
}
