import Foundation
import SwiftUI
import CoreLocation

@MainActor
class FoodEventsViewModel: ObservableObject {
    @Published var foodEvents: [FoodEvent] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var selectedEventForDetail: FoodEvent?
    @Published var currentUser: User

    struct LeaderboardEntry: Identifiable {
        let id: UUID
        let userName: String
        var points: Int
    }

    struct UserStats {
        var eventsPosted: Int
        var eventsAttended: Int
        var commentsMade: Int
        var leaderboardRank: Int
        var points: Int
        var impactScore: Int  // Total attendees across user's events
    }

    // Computed property for user's recent events
    var userRecentEvents: [FoodEvent] {
        foodEvents
            .filter { $0.createdBy == currentUser.username }
            .sorted { $0.startTime > $1.startTime }
    }

    init() {
        // Initialize with default user (no backend yet)
        self.currentUser = User(
            username: "Anonymous",
            email: "user@berkeley.edu",
            memberSince: Date()
        )
    }
    
    func addFoodEvent(_ event: FoodEvent) {
        foodEvents.append(event)
        updateLeaderboard(userName: event.createdBy)
    }
    
    func addComment(to eventId: UUID, text: String, userName: String? = nil) {
        guard let eventIndex = foodEvents.firstIndex(where: { $0.id == eventId }) else { return }

        let comment = FoodEvent.Comment(
            id: UUID(),
            text: text,
            userName: userName ?? currentUser.username,
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

    // MARK: - User Profile Methods

    func getUserStats() -> UserStats {
        let eventsPosted = foodEvents.filter { $0.createdBy == currentUser.username }.count

        let eventsAttended = foodEvents.filter { event in
            event.attendees.contains { $0.userId == currentUser.id.uuidString && $0.status == .going }
        }.count

        let commentsMade = foodEvents.reduce(0) { total, event in
            total + event.comments.filter { $0.userName == currentUser.username }.count
        }

        let userEntry = leaderboard.first { $0.userName == currentUser.username }
        let leaderboardRank = userEntry != nil ? (leaderboard.firstIndex(where: { $0.userName == currentUser.username }) ?? -1) + 1 : 0
        let points = userEntry?.points ?? 0

        // Impact score: total people who attended user's events
        let impactScore = foodEvents
            .filter { $0.createdBy == currentUser.username }
            .reduce(0) { total, event in
                total + event.attendees.filter { $0.status == .going }.count
            }

        return UserStats(
            eventsPosted: eventsPosted,
            eventsAttended: eventsAttended,
            commentsMade: commentsMade,
            leaderboardRank: leaderboardRank,
            points: points,
            impactScore: impactScore
        )
    }

    func updateUsername(_ newUsername: String) {
        guard !newUsername.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let oldUsername = currentUser.username
        currentUser.username = newUsername

        // Update all events created by this user
        for index in foodEvents.indices {
            if foodEvents[index].createdBy == oldUsername {
                foodEvents[index].createdBy = newUsername
            }

            // Update comments
            for commentIndex in foodEvents[index].comments.indices {
                if foodEvents[index].comments[commentIndex].userName == oldUsername {
                    foodEvents[index].comments[commentIndex].userName = newUsername
                }
            }
        }

        // Update leaderboard
        if let leaderboardIndex = leaderboard.firstIndex(where: { $0.userName == oldUsername }) {
            leaderboard[leaderboardIndex] = LeaderboardEntry(
                id: leaderboard[leaderboardIndex].id,
                userName: newUsername,
                points: leaderboard[leaderboardIndex].points
            )
        }
    }

    func updateProfileImage(_ imageData: Data) {
        currentUser.profileImageData = imageData
    }

    func updateAttendance(eventId: UUID, status: FoodEvent.AttendanceStatus) {
        guard let eventIndex = foodEvents.firstIndex(where: { $0.id == eventId }) else { return }

        // Remove existing attendance entry if any
        foodEvents[eventIndex].attendees.removeAll { $0.userId == currentUser.id.uuidString }

        // Add new attendance
        let attendee = FoodEvent.Attendee(
            id: UUID(),
            userId: currentUser.id.uuidString,
            status: status
        )
        foodEvents[eventIndex].attendees.append(attendee)
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