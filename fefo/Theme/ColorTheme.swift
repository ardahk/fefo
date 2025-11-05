import SwiftUI

struct ColorTheme {
    // Primary app colors
    static let primary = Color.blue
    static let secondary = Color.orange
    
    // Background colors
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    
    // Text colors
    static let text = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    
    // Semantic colors for consistent UI
    static let primaryGreen = Color.green  // Used for success states and special accents
    static let darkGray = Color(uiColor: .label)  // Primary text color
    static let softGray = Color(uiColor: .secondaryLabel)  // Secondary text color
    
    // Accent colors for stats and features
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
} 