import SwiftUI

struct TextStyles {
    static func title(_ text: String) -> some View {
        Text(text)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(ColorTheme.text)
    }
    
    static func subtitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(ColorTheme.secondaryText)
    }
    
    static func body(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundColor(ColorTheme.text)
            .lineSpacing(4)
    }
} 