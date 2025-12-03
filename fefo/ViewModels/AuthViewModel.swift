//
//  AuthViewModel.swift
//  fefo
//
//  Manages authentication flow state and logic
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var authFlowState: AuthFlowState = .welcome
    @Published var email: String = ""
    @Published var username: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var usernameAvailability: UsernameAvailability = .unknown
    
    private let authService = AuthenticationService()
    private let usernameService = UsernameService()
    private let userService = UserService()
    private var usernameCheckTask: Task<Void, Never>?
    
    enum AuthFlowState {
        case welcome
        case signUpSignIn
        case verificationPending(email: String)
        case usernameCreation(email: String, userId: String)
        case authenticated
    }
    
    enum UsernameAvailability {
        case unknown
        case checking
        case available
        case taken
        case invalid
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String) async {
        self.email = email.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Validate email
        if let emailError = ValidationService.validateEmail(self.email) {
            errorMessage = emailError
            return
        }
        
        // Validate password
        if let passwordError = ValidationService.validatePassword(password) {
            errorMessage = passwordError
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await authService.signUp(email: self.email, password: password)
            
            // Account created, verification email sent - wait for verification
            authFlowState = .verificationPending(email: self.email)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async {
        self.email = email.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Validate email
        if let emailError = ValidationService.validateEmail(self.email) {
            errorMessage = emailError
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let userId = try await authService.signIn(email: self.email, password: password)
            
            // Check if user already has a profile
            let userExists = try await userService.userExists(userId: userId)
            
            if userExists {
                // Existing user - go straight to app
                authFlowState = .authenticated
            } else {
                // Edge case: user authenticated but no profile (shouldn't happen normally)
                // Create username anyway
                authFlowState = .usernameCreation(email: self.email, userId: userId)
            }
        } catch let error as AuthenticationService.AuthError {
            // If email not verified, send to verification screen
            if case .emailNotVerified = error {
                authFlowState = .verificationPending(email: self.email)
            }
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Email Verification
    
    func resendVerificationEmail() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.sendVerificationEmail()
            errorMessage = nil // Clear any error and show success via the view
        } catch {
            errorMessage = "Failed to send email. Please try again."
        }
        
        isLoading = false
    }
    
    func checkEmailVerification() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔍 Checking email verification status...")
            let isVerified = try await authService.checkEmailVerified()
            print("✅ Email verified status: \(isVerified)")
            
            if isVerified {
                // Email is verified, get user ID and proceed to username creation
                guard let userId = authService.currentUser?.uid else {
                    print("❌ No user ID found after verification")
                    errorMessage = "Something went wrong. Please try signing in again."
                    authFlowState = .signUpSignIn
                    isLoading = false
                    return
                }
                
                print("✅ User ID: \(userId)")
                
                // Check if user already has a profile
                let userExists = try await userService.userExists(userId: userId)
                print("✅ User exists in database: \(userExists)")
                
                if userExists {
                    // Existing user with profile - go to app
                    authFlowState = .authenticated
                } else {
                    // New user - create username
                    authFlowState = .usernameCreation(email: email, userId: userId)
                }
            } else {
                print("⚠️ Email not verified yet")
                errorMessage = "Email not verified yet. Please check your inbox and click the verification link."
            }
        } catch let error {
            print("❌ Error checking verification: \(error.localizedDescription)")
            if let authError = error as? AuthenticationService.AuthError {
                // If credential expired, ask user to sign in again
                if case .credentialExpired = authError {
                    errorMessage = "Please sign in again to continue. Your email has been verified!"
                    // Navigate back to sign in after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.authFlowState = .signUpSignIn
                    }
                } else {
                    errorMessage = authError.localizedDescription
                }
            } else {
                errorMessage = "Failed to check verification status: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Username Validation
    
    func checkUsernameAvailability(_ username: String) {
        // Cancel previous check
        usernameCheckTask?.cancel()
        
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        
        // Validate format first
        if trimmedUsername.isEmpty {
            usernameAvailability = .unknown
            return
        }
        
        if ValidationService.validateUsername(trimmedUsername) != nil {
            usernameAvailability = .invalid
            return
        }
        
        usernameAvailability = .checking
        
        usernameCheckTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            guard !Task.isCancelled else { return }
            
            do {
                let isAvailable = try await usernameService.isUsernameAvailable(trimmedUsername)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.usernameAvailability = isAvailable ? .available : .taken
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.usernameAvailability = .unknown
                }
            }
        }
    }
    
    // MARK: - Create Account
    
    func createAccount(email: String, userId: String, username: String) async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        
        // Final validation
        if let error = ValidationService.validateUsername(trimmedUsername) {
            errorMessage = error
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Reserve username
            try await usernameService.reserveUsername(trimmedUsername, for: userId)
            
            // Create user profile
            try await userService.createUser(userId: userId, email: email, username: trimmedUsername)
            
            // Success - go to app
            authFlowState = .authenticated
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try authService.signOut()
            authFlowState = .welcome
            email = ""
            username = ""
            errorMessage = nil
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Reset State
    
    func resetToWelcome() {
        authFlowState = .welcome
        email = ""
        username = ""
        errorMessage = nil
        usernameAvailability = .unknown
    }
}

