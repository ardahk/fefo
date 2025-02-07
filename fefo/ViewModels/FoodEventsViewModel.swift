import Foundation
import SwiftUI
import CoreLocation

@MainActor
class FoodEventsViewModel: ObservableObject {
    @Published var foodEvents: [FoodEvent] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    
    struct LeaderboardEntry: Identifiable {
        let id: UUID
        let userName: String
        var points: Int
    }
    
    func addFoodEvent(_ event: FoodEvent) {
        foodEvents.append(event)
        updateLeaderboard(userName: event.createdBy)
    }
    
    func addComment(to eventId: UUID, text: String, userName: String = "Anonymous") {
        guard let eventIndex = foodEvents.firstIndex(where: { $0.id == eventId }) else { return }
        
        let comment = FoodEvent.Comment(
            id: UUID(),
            text: text,
            userName: userName,
            timestamp: Date()
        )
        
        foodEvents[eventIndex].comments.append(comment)
        
        // Check if event is still active
        updateEventStatus(eventId)
    }
    
    func updateEventStatus(_ eventId: UUID) {
        guard let eventIndex = foodEvents.firstIndex(where: { $0.id == eventId }) else { return }
        
        // Update isActive based on current time and end time
        foodEvents[eventIndex].isActive = foodEvents[eventIndex].endTime > Date()
    }
    
    private func updateLeaderboard(userName: String) {
        if let index = leaderboard.firstIndex(where: { $0.userName == userName }) {
            leaderboard[index].points += 1
        } else {
            leaderboard.append(LeaderboardEntry(id: UUID(), userName: userName, points: 1))
        }
        leaderboard.sort { $0.points > $1.points }
    }
    
    // MARK: - Sample Data
    func loadSampleData() {
        let sampleEvents = [
            FoodEvent(
                id: UUID(),
                title: "Pizza at CS Building",
                description: "Free pizza for CS department seminar",
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                buildingName: "Computer Science Building",
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                createdBy: "CS Department",
                isActive: true,
                comments: [],
                tags: [.freeFood, .academic, .seminar],
                attendees: []
            ),
            FoodEvent(
                id: UUID(),
                title: "Donuts at Library",
                description: "Study break snacks",
                location: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
                buildingName: "Main Library",
                startTime: Date().addingTimeInterval(1800),
                endTime: Date().addingTimeInterval(7200),
                createdBy: "Library Staff",
                isActive: true,
                comments: [],
                tags: [.snacks, .social],
                attendees: []
            )
        ]
        
        foodEvents.append(contentsOf: sampleEvents)
        
        // Add sample leaderboard entries
        updateLeaderboard(userName: "CS Department")
        updateLeaderboard(userName: "Library Staff")
    }
} 