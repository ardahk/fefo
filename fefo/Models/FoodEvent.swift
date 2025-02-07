import Foundation
import CoreLocation
import SwiftUI

struct FoodEvent: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var location: CLLocationCoordinate2D
    var buildingName: String
    var startTime: Date
    var endTime: Date
    var createdBy: String
    var isActive: Bool
    var comments: [Comment]
    var tags: [EventTag]
    var attendees: [Attendee]
    
    struct Comment: Identifiable, Codable {
        let id: UUID
        var text: String
        var userName: String
        var timestamp: Date
    }
    
    struct Attendee: Identifiable, Codable {
        let id: UUID
        let userId: String
        var status: AttendanceStatus
    }
    
    enum AttendanceStatus: String, Codable {
        case going
        case maybe
        case notGoing
    }
}

// Extension to make CLLocationCoordinate2D codable
extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
} 