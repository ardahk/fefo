//
//  UsernameCreationView.swift
//  fefo
//
//  Username creation with real-time availability checking
//

import SwiftUI

struct UsernameCreationView: View {
    @ObservedObject var viewModel: AuthViewModel
    let email: String
    let userId: String
    
    @State private var username: String = ""
    @FocusState private var isUsernameFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("Create your username")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ColorTheme.text)
                
                Text("Choose a unique username for your profile")
                    .font(.body)
                    .foregroundColor(ColorTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 20)
            
            Spacer().frame(height: 40)
            
            // Username Input
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "at")
                        .foregroundColor(ColorTheme.secondaryText)
                        .frame(width: 20)
                    
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isUsernameFocused)
                        .onChange(of: username) { _, newValue in
                            viewModel.checkUsernameAvailability(newValue)
                        }
                    
                    // Availability Indicator
                    availabilityIndicator
                }
                .padding()
                .background(ColorTheme.secondaryBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1.5)
                )
                
                // Validation Messages
                VStack(alignment: .leading, spacing: 8) {
                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if !username.isEmpty {
                        validationMessage
                    }
                    
                    // Requirements
                    Text("Requirements:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ColorTheme.secondaryText)
                    
                    ValidationRequirement(
                        text: "3-20 characters",
                        isMet: username.count >= 3 && username.count <= 20
                    )
                    
                    ValidationRequirement(
                        text: "Start with a letter",
                        isMet: !username.isEmpty && username.first!.isLetter
                    )
                    
                    ValidationRequirement(
                        text: "Letters, numbers, and underscores only",
                        isMet: ValidationService.isValidUsernameFormat(username) || username.isEmpty
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Create Account Button
            AuthButton(
                title: "Create Account",
                isLoading: viewModel.isLoading,
                action: {
                    Task {
                        await viewModel.createAccount(email: email, userId: userId, username: username)
                    }
                }
            )
            .disabled(!canCreateAccount)
            .opacity(canCreateAccount ? 1.0 : 0.5)
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTheme.background)
        .onAppear {
            isUsernameFocused = true
        }
    }
    
    // MARK: - Computed Properties
    
    private var availabilityIndicator: some View {
        Group {
            switch viewModel.usernameAvailability {
            case .unknown:
                EmptyView()
            case .checking:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ColorTheme.primary))
            case .available:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .taken:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .invalid:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .frame(width: 24, height: 24)
    }
    
    private var borderColor: Color {
        switch viewModel.usernameAvailability {
        case .available:
            return .green
        case .taken:
            return .red
        case .invalid:
            return .orange
        default:
            return ColorTheme.primary.opacity(0.2)
        }
    }
    
    private var validationMessage: some View {
        Group {
            switch viewModel.usernameAvailability {
            case .checking:
                Text("Checking availability...")
                    .font(.caption)
                    .foregroundColor(ColorTheme.secondaryText)
            case .available:
                Text("Username is available!")
                    .font(.caption)
                    .foregroundColor(.green)
            case .taken:
                Text("Username is already taken")
                    .font(.caption)
                    .foregroundColor(.red)
            case .invalid:
                Text("Invalid username format")
                    .font(.caption)
                    .foregroundColor(.orange)
            case .unknown:
                EmptyView()
            }
        }
    }
    
    private var canCreateAccount: Bool {
        !username.isEmpty &&
        viewModel.usernameAvailability == .available &&
        !viewModel.isLoading
    }
}

struct ValidationRequirement: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isMet ? .green : ColorTheme.secondaryText)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? ColorTheme.text : ColorTheme.secondaryText)
        }
    }
}

#Preview {
    UsernameCreationView(
        viewModel: AuthViewModel(),
        email: "test@berkeley.edu",
        userId: "test-user-id"
    )
}

