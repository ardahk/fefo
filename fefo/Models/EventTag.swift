import SwiftUI

extension FoodEvent {
    enum EventTag: String, Codable, CaseIterable {
        case freeFood = "Free Food!"
        case snacks = "Snacks"
        case drinks = "Drinks"
        case club = "Club"
        case seminar = "Seminar"
        case workshop = "Workshop"
        case social = "Social"
        case academic = "Academic"
        case sports = "Sports"
        case cultural = "Cultural"
        
        var color: Color {
            switch self {
            case .freeFood: return .red
            case .snacks: return .orange
            case .drinks: return .blue
            case .club: return .purple
            case .seminar: return .green
            case .workshop: return .indigo
            case .social: return .pink
            case .academic: return .brown
            case .sports: return .mint
            case .cultural: return .teal
            }
        }
    }
} 