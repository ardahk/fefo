//
//  EmailVerificationPendingView.swift
//  fefo
//
//  Waiting for email verification screen
//

import SwiftUI

struct EmailVerificationPendingView: View {
    @ObservedObject var viewModel: AuthViewModel
    let email: String
    @State private var showResendSuccess = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)
            
            // Icon
            ZStack {
                Circle()
                    .fill(ColorTheme.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ColorTheme.primary)
            }
            .padding(.bottom, 32)
            
            // Title
            Text("Verify Your Email")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(ColorTheme.text)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
            
            // Instructions
            VStack(spacing: 8) {
                Text("We sent a verification link to:")
                    .font(.body)
                    .foregroundColor(ColorTheme.secondaryText)
                
                Text(email)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTheme.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ColorTheme.secondaryBackground)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            
            // Steps
            VStack(alignment: .leading, spacing: 16) {
                StepRow(number: 1, text: "Check your inbox (and spam folder)")
                StepRow(number: 2, text: "Click the verification link")
                StepRow(number: 3, text: "Come back here and tap Continue")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            
            Spacer()
            
            // Resend success message
            if showResendSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Email sent! Check your inbox.")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding(.bottom, 12)
            }
            
            // Error message
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            }
            
            // Resend Button
            Button(action: {
                Task {
                    await viewModel.resendVerificationEmail()
                    if viewModel.errorMessage == nil {
                        showResendSuccess = true
                        // Hide success message after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showResendSuccess = false
                        }
                    }
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ColorTheme.primary))
                    } else {
                        Image(systemName: "arrow.clockwise")
                        Text("Resend Email")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ColorTheme.secondaryBackground)
                .foregroundColor(ColorTheme.primary)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal, 32)
            .padding(.bottom, 12)
            
            // Continue Button
            AuthButton(
                title: "I've Verified - Continue",
                isLoading: viewModel.isLoading,
                action: {
                    Task {
                        // In emulator, verification check often fails due to token expiry.
                        // We'll try to check, but if it fails, we'll guide user to sign in.
                        await viewModel.checkEmailVerification()
                        
                        // If still not authenticated after check (likely due to error),
                        // show the sign-in option prominently
                        if case .verificationPending = viewModel.authFlowState {
                            // Force a specific message if generic error appeared
                            if viewModel.errorMessage != nil {
                                viewModel.errorMessage = "Verification confirmed? Please sign in to continue."
                            }
                        }
                    }
                }
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
            
            // Sign in link (if credential expired, user should sign in)
            if let error = viewModel.errorMessage, error.contains("sign in again") {
                Button(action: {
                    viewModel.authFlowState = .signUpSignIn
                }) {
                    Text("Sign In to Continue")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTheme.primary)
                }
                .padding(.bottom, 12)
            }
            
            // Sign out link
            Button(action: {
                viewModel.resetToWelcome()
            }) {
                Text("Use a different email")
                    .font(.subheadline)
                    .foregroundColor(ColorTheme.secondaryText)
            }
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTheme.background)
    }
}

struct StepRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(ColorTheme.primary)
                    .frame(width: 28, height: 28)
                
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.body)
                .foregroundColor(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

#Preview {
    EmailVerificationPendingView(viewModel: AuthViewModel(), email: "hoke@berkeley.edu")
}

