//
//  AuthenticationCoordinator.swift
//  fefo
//
//  Coordinates authentication flow and view navigation
//

import SwiftUI

struct AuthenticationCoordinator: View {
    @StateObject private var viewModel = AuthViewModel()
    
    var body: some View {
        Group {
            switch viewModel.authFlowState {
            case .welcome:
                WelcomeView(viewModel: viewModel)
                
            case .signUpSignIn:
                EmailEntryView(viewModel: viewModel)
                
            case .verificationPending(let email):
                EmailVerificationPendingView(viewModel: viewModel, email: email)
                
            case .usernameCreation(let email, let userId):
                UsernameCreationView(viewModel: viewModel, email: email, userId: userId)
                
            case .authenticated:
                // This will be replaced by main app content
                EmptyView()
            }
        }
        .onOpenURL { url in
            // Handle verification link - check if user's email is now verified
            if case .verificationPending = viewModel.authFlowState {
                Task {
                    // Small delay to ensure Firebase has processed the verification
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await viewModel.checkEmailVerification()
                }
            }
        }
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ColorTheme.primary))
                .scaleEffect(1.5)
            
            Text(message)
                .font(.body)
                .foregroundColor(ColorTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTheme.background)
    }
}

#Preview {
    AuthenticationCoordinator()
}

