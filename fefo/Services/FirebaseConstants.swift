//
//  FirebaseConstants.swift
//  fefo
//
//  Firebase collection names and constants
//

import Foundation

struct FirebaseConstants {
    // Collection names
    static let usersCollection = "users"
    static let usernamesCollection = "usernames"
    static let eventsCollection = "events"
    static let commentsCollection = "comments"
    static let attendanceCollection = "attendance"
    
    // Validation constants
    static let minUsernameLength = 3
    static let maxUsernameLength = 20
    static let berkeleyEmailDomain = "@berkeley.edu"
    
    // Reserved usernames
    static let reservedUsernames = [
        "admin", "fefo", "berkeley", "official", "support",
        "help", "team", "staff", "moderator", "mod"
    ]
}

