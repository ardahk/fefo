//
//  EventService.swift
//  fefo
//
//  Handles event operations in Firestore
//

import Foundation
import FirebaseFirestore
import CoreLocation

@MainActor
class EventService {
    private let db = Firestore.firestore()
    
    enum EventError: LocalizedError {
        case eventNotFound
        case creationFailed
        case updateFailed
        case fetchFailed
        case networkError
        case unknownError(String)
        
        var errorDescription: String? {
            switch self {
            case .eventNotFound:
                return "Event not found"
            case .creationFailed:
                return "Failed to create event"
            case .updateFailed:
                return "Failed to update event"
            case .fetchFailed:
                return "Failed to load events"
            case .networkError:
                return "Network error. Please try again."
            case .unknownError(let message):
                return message
            }
        }
    }
    
    // MARK: - Create Event
    
    func createEvent(_ event: FoodEvent) async throws {
        let eventData: [String: Any] = [
            "id": event.id,
            "title": event.title,
            "description": event.description,
            "location": GeoPoint(latitude: event.location.latitude, longitude: event.location.longitude),
            "buildingName": event.buildingName,
            "startTime": Timestamp(date: event.startTime),
            "endTime": Timestamp(date: event.endTime),
            "createdBy": event.createdBy,
            "isActive": event.isActive,
            "comments": event.comments.map { comment in
                [
                    "id": comment.id,
                    "text": comment.text,
                    "userName": comment.userName,
                    "timestamp": Timestamp(date: comment.timestamp)
                ]
            },
            "tags": event.tags.map { $0.rawValue },
            "attendees": event.attendees.map { attendee in
                [
                    "id": attendee.id,
                    "userId": attendee.userId,
                    "status": attendee.status.rawValue
                ]
            }
        ]
        
        do {
            try await db.collection(FirebaseConstants.eventsCollection)
                .document(event.id)
                .setData(eventData)
        } catch {
            throw EventError.creationFailed
        }
    }
    
    // MARK: - Fetch Events
    
    func fetchEvents() async throws -> [FoodEvent] {
        do {
            // Fetch all events for now to ensure stats are correct
            // In production, you should paginate or filter by date/region
            let snapshot = try await db.collection(FirebaseConstants.eventsCollection)
                .getDocuments()
            
            var events: [FoodEvent] = []
            
            for document in snapshot.documents {
                let data = document.data()
                if let event = parseEvent(from: data) {
                    events.append(event)
                }
            }
            
            return events
        } catch {
            throw EventError.fetchFailed
        }
    }
    
    // MARK: - Update Event (Comments/Attendance)
    
    func updateEvent(_ event: FoodEvent) async throws {
        // Similar to create, but updating existing doc
        // Ideally we should use updateData with specific fields, but for now full overwrite is easier to sync state
        try await createEvent(event)
    }
    
    // Helper to parse Firestore data to FoodEvent
    private func parseEvent(from data: [String: Any]) -> FoodEvent? {
        guard
            let id = data["id"] as? String,
            let title = data["title"] as? String,
            let description = data["description"] as? String,
            let geoPoint = data["location"] as? GeoPoint,
            let buildingName = data["buildingName"] as? String,
            let startTimeTs = data["startTime"] as? Timestamp,
            let endTimeTs = data["endTime"] as? Timestamp,
            let createdBy = data["createdBy"] as? String
        else {
            return nil
        }
        
        let isActive = data["isActive"] as? Bool ?? true
        
        // Parse Tags
        let tagsData = data["tags"] as? [String] ?? []
        let tags = tagsData.compactMap { FoodEvent.EventTag(rawValue: $0) }
        
        // Parse Comments
        let commentsData = data["comments"] as? [[String: Any]] ?? []
        let comments = commentsData.compactMap { dict -> FoodEvent.Comment? in
            guard
                let id = dict["id"] as? String,
                let text = dict["text"] as? String,
                let userName = dict["userName"] as? String,
                let timestampTs = dict["timestamp"] as? Timestamp
            else { return nil }
            
            return FoodEvent.Comment(
                id: id,
                text: text,
                userName: userName,
                timestamp: timestampTs.dateValue()
            )
        }
        
        // Parse Attendees
        let attendeesData = data["attendees"] as? [[String: Any]] ?? []
        let attendees = attendeesData.compactMap { dict -> FoodEvent.Attendee? in
            guard
                let id = dict["id"] as? String,
                let userId = dict["userId"] as? String,
                let statusRaw = dict["status"] as? String,
                let status = FoodEvent.AttendanceStatus(rawValue: statusRaw)
            else { return nil }
            
            return FoodEvent.Attendee(
                id: id,
                userId: userId,
                status: status
            )
        }
        
        return FoodEvent(
            id: id,
            title: title,
            description: description,
            location: CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude),
            buildingName: buildingName,
            startTime: startTimeTs.dateValue(),
            endTime: endTimeTs.dateValue(),
            createdBy: createdBy,
            isActive: isActive,
            comments: comments,
            tags: tags,
            attendees: attendees
        )
    }
}

