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

        var icon: String {
            switch self {
            case .freeFood: return "fork.knife"
            case .snacks: return "cup.and.saucer.fill"
            case .drinks: return "mug.fill"
            case .club: return "person.3.fill"
            case .seminar: return "person.wave.2.fill"
            case .workshop: return "hammer.fill"
            case .social: return "party.popper.fill"
            case .academic: return "book.fill"
            case .sports: return "figure.run"
            case .cultural: return "theatermasks.fill"
            }
        }
    }
} 