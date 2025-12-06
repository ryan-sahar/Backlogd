//
//  LoginView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Login screen UI using Firebase Auth via AuthViewModel.
//

import SwiftUI

struct LoginView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showValidationError: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backlogBackground.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Backlog’d")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.backlogPrimary)
                        
                        Text("Track your games, write reviews, and share with friends.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.backlogSecondary)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 80)
                    
                    // Fields
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color.backlogCard)
                            .cornerRadius(12)
                            .foregroundColor(.backlogPrimary)
                        
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color.backlogCard)
                            .cornerRadius(12)
                            .foregroundColor(.backlogPrimary)
                    }
                    .padding(.horizontal)
                    
                    // Sign in button
                    Button(action: handleLogin) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                        Text("Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                            .background(Color.backlogAccentRed)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    .disabled(authViewModel.isLoading)
                    .padding(.horizontal)
                    
                    // Error messages
                    if showValidationError {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                        Text("Please enter both email and password.")
                            .foregroundColor(.red)
                            .font(.subheadline)
                        }
                        .padding(.horizontal)
                    }
                    
                    if let authError = authViewModel.authErrorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        Text(authError)
                            .foregroundColor(.red)
                            .font(.subheadline)
                        }
                        .multilineTextAlignment(.leading)
                            .padding(.horizontal)
                    }
                    
                    NavigationLink {
                        RegisterView()
                    } label: {
                        Text("Create an account")
                            .font(.subheadline)
                            .foregroundColor(.backlogSecondary)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
        }
    }
    
    private func handleLogin() {
        if email.isEmpty || password.isEmpty {
            showValidationError = true
            return
        }
        showValidationError = false
        authViewModel.login(email: email, password: password)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}

