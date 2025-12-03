import Foundation
import SwiftUI
import CoreLocation
// import FirebaseAuth  // Commented out for demo

@MainActor
class FoodEventsViewModel: ObservableObject {
    @Published var foodEvents: [FoodEvent] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var selectedEventForDetail: FoodEvent?
    @Published var currentUser: User
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Commented out for demo - using local storage only
    // private let eventService = EventService()
    // private let userService = UserService()

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
        // Initialize with demo user (Firebase auth commented out)
        self.currentUser = User(
            id: UUID().uuidString,
            username: "Arda",
            email: "demo@fefo.app",
            memberSince: Date()
        )
    }
    
    func fetchCurrentUser() async {
        // Commented out for demo - using local user
        // guard let userId = Auth.auth().currentUser?.uid else { return }
        // do {
        //     self.currentUser = try await userService.fetchUser(userId: userId)
        // } catch {
        //     print("Error fetching user: \(error.localizedDescription)")
        // }
    }
    
    func loadEvents() async {
        // Commented out for demo - using local events
        // isLoading = true
        // do {
        //     let events = try await eventService.fetchEvents()
        //     self.foodEvents = events
        //     
        //     // Rebuild leaderboard from events
        //     self.leaderboard = []
        //     for event in events {
        //         updateLeaderboard(userName: event.createdBy)
        //     }
        // } catch {
        //     self.errorMessage = "Failed to load events"
        // }
        // isLoading = false
    }
    
    func addFoodEvent(_ event: FoodEvent) {
        // Local-only for demo (Firebase commented out)
        foodEvents.append(event)
        updateLeaderboard(userName: event.createdBy)
        
        // Original Firebase code:
        // Task {
        //     do {
        //         try await eventService.createEvent(event)
        //         await loadEvents() // Reload to get fresh state
        //     } catch {
        //         print("Error creating event: \(error)")
        //     }
        // }
    }
    
    func addComment(to eventId: String, text: String, userName: String? = nil) {
        guard let index = foodEvents.firstIndex(where: { $0.id == eventId }) else { return }
        
        let comment = FoodEvent.Comment(
            id: UUID().uuidString,
            text: text,
            userName: userName ?? currentUser.username,
            timestamp: Date()
        )
        foodEvents[index].comments.append(comment)
        
        // Original Firebase code:
        // Task {
        //     do {
        //         try await eventService.updateEvent(updatedEvent)
        //         if let index = foodEvents.firstIndex(where: { $0.id == eventId }) {
        //             foodEvents[index] = updatedEvent
        //         }
        //     } catch {
        //         print("Error adding comment: \(error)")
        //     }
        // }
    }
    
    func updateEventStatus(_ eventId: String) {
        // This is logic logic, arguably should be done by backend or checking dates
        guard let index = foodEvents.firstIndex(where: { $0.id == eventId }) else { return }
        foodEvents[index].isActive = foodEvents[index].endTime > Date()
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
        // Safe for empty arrays - all filters and reduces return 0 when empty
        
        let eventsPosted = foodEvents.filter { $0.createdBy == currentUser.username }.count

        let eventsAttended = foodEvents.filter { event in
            event.attendees.contains { $0.userId == currentUser.id && $0.status == .going }
        }.count

        let commentsMade = foodEvents.reduce(0) { total, event in
            total + event.comments.filter { $0.userName == currentUser.username }.count
        }


        // Leaderboard rank calculation - returns 0 if user not on leaderboard
        let userEntry = leaderboard.first { $0.userName == currentUser.username }
        let leaderboardRank: Int
        if let userEntry = userEntry, let index = leaderboard.firstIndex(where: { $0.userName == currentUser.username }) {
            leaderboardRank = index + 1
        } else {
            leaderboardRank = 0
        }
        let points = userEntry?.points ?? 0

        // Impact score: total people who attended user's events
        let impactScore = foodEvents
            .filter { $0.createdBy == currentUser.username }
            .reduce(0) { total, event in
                total + event.attendees.filter { $0.status == .going }.count
            }

        return UserStats(
            eventsPosted: max(0, eventsPosted),
            eventsAttended: max(0, eventsAttended),
            commentsMade: max(0, commentsMade),
            leaderboardRank: max(0, leaderboardRank),
            points: max(0, points),
            impactScore: max(0, impactScore)
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

    func updateAttendance(eventId: String, status: FoodEvent.AttendanceStatus) {
        guard let index = foodEvents.firstIndex(where: { $0.id == eventId }) else { return }
        
        // Remove existing attendance entry if any
        foodEvents[index].attendees.removeAll { $0.userId == currentUser.id }
        
        // Add new attendance
        let attendee = FoodEvent.Attendee(
            id: UUID().uuidString,
            userId: currentUser.id,
            status: status
        )
        foodEvents[index].attendees.append(attendee)
        
        // Original Firebase code:
        // Task {
        //     do {
        //         try await eventService.updateEvent(updatedEvent)
        //         if let index = foodEvents.firstIndex(where: { $0.id == eventId }) {
        //             foodEvents[index] = updatedEvent
        //         }
        //     } catch {
        //         print("Error updating attendance: \(error)")
        //     }
        // }
    }

    // MARK: - Sample Data
    func loadSampleData() {
        // Clear existing data to avoid duplicates
        foodEvents.removeAll()
        leaderboard.removeAll()
        
        // Ensure demo user is set
        currentUser = User(
            id: "demo-user-arda",
            username: "Arda",
            email: "demo@fefo.app",
            memberSince: Date()
        )
        
        let now = Date()
        
        // Events created by current user (to show in profile)
        let userEvent1 = FoodEvent(
            id: UUID().uuidString,
            title: "Free Burritos at MLK",
            description: "Leftover burritos from our club meeting! Come grab some while they last.",
            location: CLLocationCoordinate2D(latitude: 37.8695, longitude: -122.2605),
            buildingName: "MLK Student Union",
            startTime: now.addingTimeInterval(-1800),
            endTime: now.addingTimeInterval(1800),
            createdBy: currentUser.username,
            isActive: true,
            comments: [
                FoodEvent.Comment(id: UUID().uuidString, text: "Thanks for sharing!", userName: "CS Department", timestamp: now.addingTimeInterval(-900)),
                FoodEvent.Comment(id: UUID().uuidString, text: "On my way!", userName: "Library Staff", timestamp: now.addingTimeInterval(-600))
            ],
            tags: [.freeFood, .social],
            attendees: [
                FoodEvent.Attendee(id: UUID().uuidString, userId: UUID().uuidString, status: .going),
                FoodEvent.Attendee(id: UUID().uuidString, userId: UUID().uuidString, status: .going),
                FoodEvent.Attendee(id: UUID().uuidString, userId: UUID().uuidString, status: .maybe)
            ]
        )
        
        let userEvent2 = FoodEvent(
            id: UUID().uuidString,
            title: "Coffee & Cookies Study Session",
            description: "Join us for a chill study session with free coffee and homemade cookies!",
            location: CLLocationCoordinate2D(latitude: 37.8725, longitude: -122.2597),
            buildingName: "Doe Memorial Library",
            startTime: now.addingTimeInterval(7200),
            endTime: now.addingTimeInterval(14400),
            createdBy: currentUser.username,
            isActive: true,
            comments: [],
            tags: [.snacks, .academic, .social],
            attendees: [
                FoodEvent.Attendee(id: UUID().uuidString, userId: UUID().uuidString, status: .going)
            ]
        )
        
        // Events by other users where current user is attending
        let event1 = FoodEvent(
                id: UUID().uuidString,
                title: "Pizza at CS Building",
            description: "Free pizza for CS department seminar. All welcome!",
            location: CLLocationCoordinate2D(latitude: 37.8749, longitude: -122.2594),
            buildingName: "Soda Hall",
            startTime: now.addingTimeInterval(3600),
            endTime: now.addingTimeInterval(7200),
                createdBy: "CS Department",
                isActive: true,
            comments: [
                FoodEvent.Comment(id: UUID().uuidString, text: "Will there be vegetarian options?", userName: currentUser.username, timestamp: now.addingTimeInterval(-1200)),
                FoodEvent.Comment(id: UUID().uuidString, text: "Yes! Half will be veggie.", userName: "CS Department", timestamp: now.addingTimeInterval(-900))
            ],
                tags: [.freeFood, .academic, .seminar],
            attendees: [
                FoodEvent.Attendee(id: UUID().uuidString, userId: currentUser.id, status: .going),
                FoodEvent.Attendee(id: UUID().uuidString, userId: UUID().uuidString, status: .going),
                FoodEvent.Attendee(id: UUID().uuidString, userId: UUID().uuidString, status: .going)
            ]
        )
        
        let event2 = FoodEvent(
                id: UUID().uuidString,
            title: "Bagels at Library",
            description: "Study break bagels courtesy of the library staff!",
            location: CLLocationCoordinate2D(latitude: 37.8725, longitude: -122.2597),
            buildingName: "Moffitt Library",
            startTime: now.addingTimeInterval(5400),
            endTime: now.addingTimeInterval(9000),
                createdBy: "Library Staff",
            isActive: true,
            comments: [
                FoodEvent.Comment(id: UUID().uuidString, text: "Perfect timing for my study break!", userName: currentUser.username, timestamp: now.addingTimeInterval(-300))
            ],
            tags: [.snacks, .social],
            attendees: [
                FoodEvent.Attendee(id: UUID().uuidString, userId: currentUser.id, status: .going),
                FoodEvent.Attendee(id: UUID().uuidString, userId: UUID().uuidString, status: .maybe)
            ]
        )
        
        // Event by other user where current user is not attending
        let event3 = FoodEvent(
            id: UUID().uuidString,
            title: "BBQ at Memorial Glade",
            description: "End of semester BBQ celebration! Burgers, hot dogs, and veggie options.",
            location: CLLocationCoordinate2D(latitude: 37.8715, longitude: -122.2580),
            buildingName: "Memorial Glade",
            startTime: now.addingTimeInterval(86400),
            endTime: now.addingTimeInterval(93600),
            createdBy: "Student Activities",
                isActive: true,
                comments: [],
            tags: [.freeFood, .social, .cultural],
                attendees: []
            )
        
        foodEvents.append(contentsOf: [userEvent1, userEvent2, event1, event2, event3])
        
        // Update leaderboard with realistic data
        updateLeaderboard(userName: currentUser.username)
        updateLeaderboard(userName: currentUser.username) // 2 points for 2 events
        updateLeaderboard(userName: "CS Department")
        updateLeaderboard(userName: "Library Staff")
        updateLeaderboard(userName: "Student Activities")
    }
} 