import SwiftUI

struct AuthView: View {
    @StateObject private var supabase = SupabaseService.shared
    @State private var isSignUp = false

    var body: some View {
        if supabase.isAuthenticated {
            ShelvesListView()
        } else if isSignUp {
            SignUpView(isSignUp: $isSignUp)
        } else {
            LoginView(isSignUp: $isSignUp)
        }
    }
}

// MARK: - Login

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

                Text("Book Shelves")
                    .font(.system(size: 36, weight: .bold))
                    .padding(.bottom, 40)

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disabled(isLoading)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .disabled(isLoading)

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
                Button("OK", role: .cancel) {}
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
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Sign Up

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

                Text("Book Shelves")
                    .font(.system(size: 36, weight: .bold))
                    .padding(.bottom, 40)

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disabled(isLoading)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .disabled(isLoading)

                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .disabled(isLoading)

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
                Button("OK", role: .cancel) {}
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
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Helpers

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

// MARK: - Previews

#Preview {
    AuthView()
}

#Preview("Login") {
    LoginView(isSignUp: .constant(false))
}

#Preview("Sign Up") {
    SignUpView(isSignUp: .constant(true))
}
