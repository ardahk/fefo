import SwiftUI
import Foundation

struct User: Identifiable, Codable {
    let id: String
    var username: String
    var email: String
    var profileImageData: Data?  // Store image data locally (no backend)
    var memberSince: Date

    init(id: String = UUID().uuidString, username: String, email: String, profileImageData: Data? = nil, memberSince: Date = Date()) {
        self.id = id
        self.username = username
        self.email = email
        self.profileImageData = profileImageData
        self.memberSince = memberSince
    }

    // Generate color-coded avatar color from username
    var avatarColor: Color {
        let colors: [Color] = [
            ColorTheme.primaryGreen,
            .blue,
            .purple,
            .orange,
            .pink,
            .cyan,
            .indigo,
            .mint
        ]

        let hash = abs(username.hashValue)
        return colors[hash % colors.count]
    }

    // Get initials for avatar
    var initials: String {
        let components = username.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1).uppercased()
            let last = components[1].prefix(1).uppercased()
            return "\(first)\(last)"
        } else if let first = components.first {
            return String(first.prefix(2).uppercased())
        }
        return "?"
    }
}
