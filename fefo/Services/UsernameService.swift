//
//  UsernameService.swift
//  fefo
//
//  Handles username availability checking and registration
//

import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift

@MainActor
class UsernameService {
    private let db = Firestore.firestore()
    
    enum UsernameError: LocalizedError {
        case alreadyTaken
        case invalid
        case networkError
        case unknownError(String)
        
        var errorDescription: String? {
            switch self {
            case .alreadyTaken:
                return "This username is already taken"
            case .invalid:
                return "Invalid username format"
            case .networkError:
                return "Network error. Please try again."
            case .unknownError(let message):
                return message
            }
        }
    }
    
    // MARK: - Check Availability
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        // Validate format first
        guard ValidationService.isValidUsernameFormat(username) else {
            throw UsernameError.invalid
        }
        
        let lowercasedUsername = username.lowercased()
        
        do {
            let document = try await db.collection(FirebaseConstants.usernamesCollection)
                .document(lowercasedUsername)
                .getDocument()
            
            return !document.exists
        } catch {
            throw UsernameError.networkError
        }
    }
    
    // MARK: - Reserve Username
    
    func reserveUsername(_ username: String, for userId: String) async throws {
        // Validate format
        if let error = ValidationService.validateUsername(username) {
            throw UsernameError.invalid
        }
        
        let lowercasedUsername = username.lowercased()
        
        do {
            try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                let usernameRef = self.db.collection(FirebaseConstants.usernamesCollection)
                    .document(lowercasedUsername)
                
                let usernameDoc: DocumentSnapshot
                do {
                    usernameDoc = try transaction.getDocument(usernameRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                // Check if username exists
                if usernameDoc.exists {
                    // Check if it belongs to the same user (re-login case)
                    if let existingUserId = usernameDoc.data()?["userId"] as? String,
                       existingUserId == userId {
                        // Same user, allow
                        return nil
                    }
                    // Different user, reject
                    errorPointer?.pointee = NSError(
                        domain: "UsernameService",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Username already taken"]
                    )
                    return nil
                }
                
                // Reserve username
                transaction.setData([
                    "userId": userId,
                    "username": username, // Store original case
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: usernameRef)
                
                return nil
            })
        } catch {
            if error.localizedDescription.contains("already taken") {
                throw UsernameError.alreadyTaken
            }
            throw UsernameError.unknownError(error.localizedDescription)
        }
    }
    
    // MARK: - Get Username for User
    
    func getUsername(for userId: String) async throws -> String? {
        do {
            let querySnapshot = try await db.collection(FirebaseConstants.usernamesCollection)
                .whereField("userId", isEqualTo: userId)
                .limit(to: 1)
                .getDocuments()
            
            return querySnapshot.documents.first?.data()["username"] as? String
        } catch {
            throw UsernameError.networkError
        }
    }
    
    // MARK: - Delete Username (for account deletion or username change)
    
    func deleteUsername(_ username: String) async throws {
        let lowercasedUsername = username.lowercased()
        
        do {
            try await db.collection(FirebaseConstants.usernamesCollection)
                .document(lowercasedUsername)
                .delete()
        } catch {
            throw UsernameError.networkError
        }
    }
}

