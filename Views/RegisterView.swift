//
//  RegisterView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  User registration screen UI.
//  Uses AuthViewModel.register(...) to create a Firebase user.
//

import SwiftUI

struct RegisterView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.backlogBackground.ignoresSafeArea()
            
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create your Backlog’d account")
                            .font(.headline)
                            .foregroundColor(.backlogPrimary)
                        Text("We’ll use this info to personalize your gaming log.")
                            .font(.subheadline)
                            .foregroundColor(.backlogSecondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Account Info") {
                    TextField("Display Name", text: $displayName)
                        .foregroundColor(.backlogPrimary)
                    
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .foregroundColor(.backlogPrimary)
                    
                    SecureField("Password", text: $password)
                        .foregroundColor(.backlogPrimary)
                    SecureField("Confirm Password", text: $confirmPassword)
                        .foregroundColor(.backlogPrimary)
                }
                
                if let errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                }
                
                if let authError = authViewModel.authErrorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(authError)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                }
                
                Section {
                    Button(action: handleCreateAccount) {
                        if authViewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .backlogAccentRed))
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else {
                            Text("Create Account")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.backlogAccentRed)
                                .font(.headline)
                        }
                    }
                    .disabled(authViewModel.isLoading)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Sign Up")
    }
    
    private func handleCreateAccount() {
        guard !displayName.isEmpty,
              !email.isEmpty,
              !password.isEmpty,
              !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        
        errorMessage = nil
        authViewModel.register(displayName: displayName, email: email, password: password)
    }
}

#Preview {
    NavigationStack {
        RegisterView().environmentObject(AuthViewModel())
    }
}
