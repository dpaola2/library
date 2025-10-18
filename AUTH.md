## Features:

**AuthView (Router)**

- Automatically shows auth screens when logged out
- Navigates to ShelvesListView when authenticated
- Toggles between Login and Sign Up views

**LoginView**

- Email and password fields
- Form validation (email format, non-empty fields)
- Loading state with spinner
- Error handling with alerts
- "Sign Up" link to switch views

**SignUpView**

- Email, password, and confirm password fields
- Real-time password requirements display:
    - ✅ At least 6 characters
    - ✅ Passwords match
- Form validation
- Loading state with spinner
- Error handling with alerts
- "Log In" link to switch views

**User Experience:**

- Disabled form fields during loading
- Button disabled until form is valid
- Clear error messages
- Smooth transitions between views
- Keyboard-appropriate text content types

## How to use:

**1. Update your main App file:**

```swift
// BookShelvesApp.swift
import SwiftUI

@main
struct BookShelvesApp: App {
    var body: some Scene {
        WindowGroup {
            AuthView()
        }
    }
}
```

**2. Test the flow:**

- Sign up with a new email/password
- It automatically logs you in after sign up
- Log out (we'll add that next)
- Log back in with the same credentials

**Note:** Supabase's default password requirement is 6 characters minimum. The view validates this client-side before submitting.

```swift
// AuthView.swift
import SwiftUI

struct AuthView: View {
    @StateObject private var supabase = SupabaseService.shared
    @State private var isSignUp = false
    
    var body: some View {
        if supabase.isAuthenticated {
            // Navigate to main app
            ShelvesListView()
        } else {
            if isSignUp {
                SignUpView(isSignUp: $isSignUp)
            } else {
                LoginView(isSignUp: $isSignUp)
            }
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @Binding var isSignUp: Bool
    @StateObject private var supabase = SupabaseService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                // App Title/Logo
                Text("Book Shelves")
                    .font(.system(size: 36, weight: .bold))
                    .padding(.bottom, 40)
                
                // Email Field
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disabled(isLoading)
                
                // Password Field
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .disabled(isLoading)
                
                // Login Button
                Button {
                    login()
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isFormValid || isLoading)
                
                Spacer()
                
                // Switch to Sign Up
                HStack {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)
                    Button("Sign Up") {
                        isSignUp = true
                    }
                    .fontWeight(.semibold)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 32)
            .navigationTitle("Welcome Back")
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func login() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await supabase.signIn(email: email, password: password)
                // Success - view will automatically update via @Published isAuthenticated
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @Binding var isSignUp: Bool
    @StateObject private var supabase = SupabaseService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                // App Title/Logo
                Text("Book Shelves")
                    .font(.system(size: 36, weight: .bold))
                    .padding(.bottom, 40)
                
                // Email Field
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disabled(isLoading)
                
                // Password Field
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .disabled(isLoading)
                
                // Confirm Password Field
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .disabled(isLoading)
                
                // Password requirements hint
                if !password.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        PasswordRequirement(
                            text: "At least 6 characters",
                            isMet: password.count >= 6
                        )
                        PasswordRequirement(
                            text: "Passwords match",
                            isMet: password == confirmPassword && !confirmPassword.isEmpty
                        )
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Sign Up Button
                Button {
                    signUp()
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign Up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isFormValid || isLoading)
                
                Spacer()
                
                // Switch to Login
                HStack {
                    Text("Already have an account?")
                        .foregroundStyle(.secondary)
                    Button("Log In") {
                        isSignUp = false
                    }
                    .fontWeight(.semibold)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 32)
            .navigationTitle("Create Account")
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    private func signUp() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await supabase.signUp(email: email, password: password)
                // Success - view will automatically update via @Published isAuthenticated
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Helper Views

struct PasswordRequirement: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isMet ? .green : .secondary)
                .imageScale(.small)
            Text(text)
                .foregroundStyle(isMet ? .primary : .secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
}

#Preview("Login") {
    LoginView(isSignUp: .constant(false))
}

#Preview("Sign Up") {
    SignUpView(isSignUp: .constant(true))
}
```