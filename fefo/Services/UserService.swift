//
//  UserService.swift
//  fefo
//
//  Handles user profile operations in Firestore
//

import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift

@MainActor
class UserService {
    private let db = Firestore.firestore()
    
    enum UserError: LocalizedError {
        case userNotFound
        case creationFailed
        case networkError
        case unknownError(String)
        
        var errorDescription: String? {
            switch self {
            case .userNotFound:
                return "User profile not found"
            case .creationFailed:
                return "Failed to create user profile"
            case .networkError:
                return "Network error. Please try again."
            case .unknownError(let message):
                return message
            }
        }
    }
    
    // MARK: - Create User
    
    func createUser(userId: String, email: String, username: String) async throws {
        let userData: [String: Any] = [
            "email": email,
            "username": username,
            "memberSince": FieldValue.serverTimestamp(),
            "points": 0,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection(FirebaseConstants.usersCollection)
                .document(userId)
                .setData(userData)
        } catch {
            throw UserError.creationFailed
        }
    }
    
    // MARK: - Fetch User
    
    func fetchUser(userId: String) async throws -> User {
        do {
            let document = try await db.collection(FirebaseConstants.usersCollection)
                .document(userId)
                .getDocument()
            
            guard document.exists else {
                throw UserError.userNotFound
            }
            
            guard let data = document.data() else {
                throw UserError.userNotFound
            }
            
            // Parse user data
            let email = data["email"] as? String ?? ""
            let username = data["username"] as? String ?? ""
            let memberSince = (data["memberSince"] as? Timestamp)?.dateValue() ?? Date()
            
            return User(
                id: userId,
                username: username,
                email: email,
                profileImageData: nil,
                memberSince: memberSince
            )
        } catch {
            if error is UserError {
                throw error
            }
            throw UserError.networkError
        }
    }
    
    // MARK: - Update User
    
    func updateUser(userId: String, updates: [String: Any]) async throws {
        do {
            try await db.collection(FirebaseConstants.usersCollection)
                .document(userId)
                .updateData(updates)
        } catch {
            throw UserError.networkError
        }
    }
    
    // MARK: - Update Username
    
    func updateUsername(userId: String, newUsername: String) async throws {
        let updates: [String: Any] = [
            "username": newUsername,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await updateUser(userId: userId, updates: updates)
    }
    
    // MARK: - Check if User Exists
    
    func userExists(userId: String) async throws -> Bool {
        do {
            let document = try await db.collection(FirebaseConstants.usersCollection)
                .document(userId)
                .getDocument()
            
            return document.exists
        } catch {
            throw UserError.networkError
        }
    }
    
    // MARK: - Get User by Email
    
    func getUserByEmail(_ email: String) async throws -> (userId: String, username: String)? {
        do {
            let querySnapshot = try await db.collection(FirebaseConstants.usersCollection)
                .whereField("email", isEqualTo: email)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = querySnapshot.documents.first else {
                return nil
            }
            
            let username = document.data()["username"] as? String ?? ""
            return (userId: document.documentID, username: username)
        } catch {
            throw UserError.networkError
        }
    }
}

