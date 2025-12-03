//
//  WelcomeView.swift
//  fefo
//
//  Welcome screen for authentication
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Logo/Branding
            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .font(.system(size: 80))
                    .foregroundColor(ColorTheme.primary)
                
                Text("FeFo")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(ColorTheme.text)
                
                Text("Find free food at Berkeley")
                    .font(.title3)
                    .foregroundColor(ColorTheme.secondaryText)
            }
            
            Spacer()
            
            // Get Started Button
            VStack(spacing: 16) {
                AuthButton(
                    title: "Get Started",
                    isLoading: false,
                    action: {
                        viewModel.authFlowState = .signUpSignIn
                    }
                )
                
                Button(action: {
                    viewModel.authFlowState = .signUpSignIn
                }) {
                    Text("Already have an account? Sign in")
                        .font(.subheadline)
                        .foregroundColor(ColorTheme.primary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTheme.background)
    }
}

#Preview {
    WelcomeView(viewModel: AuthViewModel())
}

