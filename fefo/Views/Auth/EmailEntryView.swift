//
//  EmailEntryView.swift
//  fefo
//
//  Sign up and sign in screen with email+password
//

import SwiftUI

struct EmailEntryView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isSignUpMode: Bool = true
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, confirmPassword
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    viewModel.resetToWelcome()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(ColorTheme.primary)
                }
                .padding(.bottom, 20)
                
                Text(isSignUpMode ? "Create Account" : "Welcome Back")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ColorTheme.text)
                
                Text(isSignUpMode ? "Sign up with your @berkeley.edu email" : "Sign in to your account")
                    .font(.body)
                    .foregroundColor(ColorTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 20)
            
            Spacer().frame(height: 40)
            
            // Input Fields
            VStack(spacing: 20) {
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(ColorTheme.secondaryText)
                            .frame(width: 20)
                        
                        TextField("yourname@berkeley.edu", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                    }
                    .padding()
                    .background(ColorTheme.secondaryBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorTheme.primary.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(ColorTheme.secondaryText)
                            .frame(width: 20)
                        
                        SecureField("Password", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .password)
                    }
                    .padding()
                    .background(ColorTheme.secondaryBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorTheme.primary.opacity(0.2), lineWidth: 1)
                    )
                    
                    if isSignUpMode && !password.isEmpty {
                        Text("Minimum 8 characters with a letter and number")
                            .font(.caption)
                            .foregroundColor(ColorTheme.secondaryText)
                    }
                }
                
                // Confirm Password Field (Sign Up only)
                if isSignUpMode {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(ColorTheme.secondaryText)
                                .frame(width: 20)
                            
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .confirmPassword)
                        }
                        .padding()
                        .background(ColorTheme.secondaryBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ColorTheme.primary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                
                // Error Message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Mode Toggle
            HStack(spacing: 4) {
                Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                    .font(.subheadline)
                    .foregroundColor(ColorTheme.secondaryText)
                
                Button(action: {
                    withAnimation {
                        isSignUpMode.toggle()
                        viewModel.errorMessage = nil
                        password = ""
                        confirmPassword = ""
                    }
                }) {
                    Text(isSignUpMode ? "Sign In" : "Sign Up")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTheme.primary)
                }
            }
            .padding(.bottom, 16)
            
            // Submit Button
            AuthButton(
                title: isSignUpMode ? "Create Account" : "Sign In",
                isLoading: viewModel.isLoading,
                action: {
                    handleSubmit()
                }
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTheme.background)
        .onAppear {
            focusedField = .email
        }
    }
    
    private func handleSubmit() {
        // Clear previous error
        viewModel.errorMessage = nil
        
        if isSignUpMode {
            // Validate passwords match
            if password != confirmPassword {
                viewModel.errorMessage = "Passwords do not match"
                return
            }
            
            Task {
                await viewModel.signUp(email: email, password: password)
            }
        } else {
            Task {
                await viewModel.signIn(email: email, password: password)
            }
        }
    }
}

#Preview {
    EmailEntryView(viewModel: AuthViewModel())
}
