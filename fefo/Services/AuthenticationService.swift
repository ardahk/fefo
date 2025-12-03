//
//  AuthenticationService.swift
//  fefo
//
//  Handles Firebase Authentication with email+password
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
class AuthenticationService: ObservableObject {
    @Published var currentUser: FirebaseAuth.User?
    @Published var authState: AuthState = .unauthenticated
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    enum AuthState {
        case unauthenticated
        case authenticated(userId: String)
    }
    
    enum AuthError: LocalizedError {
        case invalidEmail
        case emailNotBerkeley
        case weakPassword
        case emailAlreadyInUse
        case userNotFound
        case wrongPassword
        case emailNotVerified
        case credentialExpired
        case networkError
        case unknownError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidEmail:
                return "Please enter a valid email address"
            case .emailNotBerkeley:
                return "Please use your @berkeley.edu email"
            case .weakPassword:
                return "Password is too weak"
            case .emailAlreadyInUse:
                return "This email is already registered. Please sign in instead."
            case .userNotFound:
                return "No account found with this email. Please sign up first."
            case .wrongPassword:
                return "Incorrect password. Please try again."
            case .emailNotVerified:
                return "Please verify your email address before signing in."
            case .credentialExpired:
                return "Your session expired. Please sign in again."
            case .networkError:
                return "Network error. Please check your connection and try again."
            case .unknownError(let message):
                return message
            }
        }
    }
    
    init() {
        // Listen to auth state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                if let user = user {
                    self?.authState = .authenticated(userId: user.uid)
                } else {
                    self?.authState = .unauthenticated
                }
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String) async throws -> String {
        // Validate Berkeley email
        guard ValidationService.isValidBerkeleyEmail(email) else {
            throw AuthError.emailNotBerkeley
        }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Send verification email
            try await result.user.sendEmailVerification()
            print("📧 Verification email sent to \(email)")
            
            return result.user.uid
        } catch let error as NSError {
            print("🔥 Firebase Auth Error:")
            print("Domain: \(error.domain)")
            print("Code: \(error.code)")
            print("Description: \(error.localizedDescription)")
            
            if error.domain == AuthErrorDomain {
                switch AuthErrorCode(_bridgedNSError: error)?.code {
                case .emailAlreadyInUse:
                    throw AuthError.emailAlreadyInUse
                case .invalidEmail:
                    throw AuthError.invalidEmail
                case .weakPassword:
                    throw AuthError.weakPassword
                case .networkError:
                    throw AuthError.networkError
                default:
                    throw AuthError.unknownError(error.localizedDescription)
                }
            }
            throw AuthError.unknownError(error.localizedDescription)
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws -> String {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Check if email is verified
            if !result.user.isEmailVerified {
                throw AuthError.emailNotVerified
            }
            
            return result.user.uid
        } catch let error as NSError {
            print("🔥 Firebase Auth Error:")
            print("Domain: \(error.domain)")
            print("Code: \(error.code)")
            print("Description: \(error.localizedDescription)")
            
            if error.domain == AuthErrorDomain {
                switch AuthErrorCode(_bridgedNSError: error)?.code {
                case .userNotFound:
                    throw AuthError.userNotFound
                case .wrongPassword:
                    throw AuthError.wrongPassword
                case .invalidEmail:
                    throw AuthError.invalidEmail
                case .networkError:
                    throw AuthError.networkError
                default:
                    throw AuthError.unknownError(error.localizedDescription)
                }
            }
            throw AuthError.unknownError(error.localizedDescription)
        }
    }
    
    // MARK: - Email Verification
    
    func sendVerificationEmail() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        do {
            try await user.sendEmailVerification()
            print("📧 Verification email sent")
        } catch {
            throw AuthError.networkError
        }
    }
    
    func checkEmailVerified() async throws -> Bool {
        guard var user = Auth.auth().currentUser else {
            print("❌ No current user found when checking verification")
            throw AuthError.userNotFound
        }
        
        print("🔍 Current user email: \(user.email ?? "none")")
        print("🔍 Current verification status before reload: \(user.isEmailVerified)")
        
        // Try to reload user to get latest email verification status
        do {
            try await user.reload()
            print("✅ User reloaded successfully")
        } catch let error as NSError {
            print("⚠️ Failed to reload user: \(error.localizedDescription)")
            
            // If credential expired, sign out and throw credential expired error
            if error.domain == AuthErrorDomain {
                if let authError = AuthErrorCode(_bridgedNSError: error)?.code,
                   authError == .userTokenExpired || authError == .invalidUserToken {
                    print("🔄 Credential expired, signing out...")
                    try? Auth.auth().signOut()
                    throw AuthError.credentialExpired
                }
            }
            // For other errors, try to continue with current user state
            print("⚠️ Continuing with current user state despite reload error")
        }
        
        // Get the updated user after reload (or use current if reload failed)
        guard let reloadedUser = Auth.auth().currentUser else {
            print("❌ No user found after reload attempt")
            throw AuthError.userNotFound
        }
        
        print("🔍 Verification status after reload: \(reloadedUser.isEmailVerified)")
        
        // Update currentUser property to reflect the reloaded state
        await MainActor.run {
            self.currentUser = reloadedUser
            print("✅ Updated currentUser property")
        }
        
        return reloadedUser.isEmailVerified
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        try Auth.auth().signOut()
        authState = .unauthenticated
    }
    
    // MARK: - Helper Methods
    
    var isAuthenticated: Bool {
        guard let user = currentUser else { return false }
        return user.isEmailVerified
    }
}

