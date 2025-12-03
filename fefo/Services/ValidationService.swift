

//
//  ValidationService.swift
//  fefo
//
//  Email and username validation logic
//

import Foundation

class ValidationService {
    
    // MARK: - Email Validation
    
    static func isValidBerkeleyEmail(_ email: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Must end with @berkeley.edu
        guard trimmedEmail.hasSuffix(FirebaseConstants.berkeleyEmailDomain) else {
            return false
        }
        
        // Basic email format validation
        let emailRegex = "^[A-Z0-9a-z._%+-]+@berkeley\\.edu$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: trimmedEmail)
    }
    
    static func validateEmail(_ email: String) -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        
        if trimmedEmail.isEmpty {
            return "Email cannot be empty"
        }
        
        if !isValidBerkeleyEmail(trimmedEmail) {
            return "Please use a valid @berkeley.edu email address"
        }
        
        return nil
    }
    
    // MARK: - Password Validation
    
    static func validatePassword(_ password: String) -> String? {
        if password.isEmpty {
            return "Password cannot be empty"
        }
        
        if password.count < 8 {
            return "Password must be at least 8 characters"
        }
        
        let hasLetter = password.rangeOfCharacter(from: .letters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        
        if !hasLetter || !hasNumber {
            return "Password must contain at least one letter and one number"
        }
        
        return nil
    }
    
    // MARK: - Username Validation
    
    static func isValidUsernameFormat(_ username: String) -> Bool {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        
        // Check length
        guard trimmedUsername.count >= FirebaseConstants.minUsernameLength &&
              trimmedUsername.count <= FirebaseConstants.maxUsernameLength else {
            return false
        }
        
        // Check characters (alphanumeric + underscore only)
        let usernameRegex = "^[a-zA-Z][a-zA-Z0-9_]*$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        
        return usernamePredicate.evaluate(with: trimmedUsername)
    }
    
    static func isReservedUsername(_ username: String) -> Bool {
        let lowercasedUsername = username.lowercased()
        return FirebaseConstants.reservedUsernames.contains(lowercasedUsername)
    }
    
    static func validateUsername(_ username: String) -> String? {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        
        if trimmedUsername.isEmpty {
            return "Username cannot be empty"
        }
        
        if trimmedUsername.count < FirebaseConstants.minUsernameLength {
            return "Username must be at least \(FirebaseConstants.minUsernameLength) characters"
        }
        
        if trimmedUsername.count > FirebaseConstants.maxUsernameLength {
            return "Username must be less than \(FirebaseConstants.maxUsernameLength) characters"
        }
        
        if !trimmedUsername.first!.isLetter {
            return "Username must start with a letter"
        }
        
        if !isValidUsernameFormat(trimmedUsername) {
            return "Username can only contain letters, numbers, and underscores"
        }
        
        if isReservedUsername(trimmedUsername) {
            return "This username is reserved"
        }
        
        return nil
    }
}

