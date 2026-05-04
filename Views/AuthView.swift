import SwiftUI
import AuthenticationServices
import Auth

struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var confirmPassword = ""
    @State private var showReset = false
    @State private var isLoading = false

    enum Mode { case signIn, signUp }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Mode picker pinned at top ─────────────────
                Picker("Mode", selection: $mode) {
                    Text("Sign In").tag(Mode.signIn)
                    Text("Create Account").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
                .padding()

                // ── Scrollable content ────────────────────────
                ScrollView {
                    VStack(spacing: 20) {

                        // Logo
                        VStack(spacing: 8) {
                            Image(systemName: "checklist")
                                .font(.system(size: 56))
                                .foregroundStyle(Color("Accent"))
                            Text("DailyList")
                                .font(.largeTitle.weight(.bold))
                            Text("Your personal daily planner")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)

                        // Fields
                        VStack(spacing: 12) {
                            if mode == .signUp {
                                AuthField(
                                    placeholder: "Your name",
                                    text: $displayName,
                                    icon: "person"
                                )
                            }

                            AuthField(
                                placeholder: "Email",
                                text: $email,
                                icon: "envelope",
                                contentType: .emailAddress,
                                keyboard: .emailAddress
                            )

                            AuthField(
                                placeholder: "Password",
                                text: $password,
                                icon: "lock",
                                contentType: .password,
                                isSecure: true
                            )

                            if mode == .signUp {
                                AuthField(
                                    placeholder: "Confirm Password",
                                    text: $confirmPassword,
                                    icon: "lock.fill",
                                    contentType: .newPassword,
                                    isSecure: true
                                )
                            }
                        }
                        .padding(.horizontal)

                        // Error
                        if let error = authVM.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Primary button
                        Button {
                            Task { await primaryAction() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(mode == .signIn ? "Sign In" : "Create Account")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(formValid ? Color("Accent") : Color.gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                        .disabled(isLoading || !formValid)

                        // Divider
                        HStack {
                            Rectangle().frame(height: 1).foregroundStyle(.separator)
                            Text("or").font(.caption).foregroundStyle(.secondary)
                            Rectangle().frame(height: 1).foregroundStyle(.separator)
                        }
                        .padding(.horizontal)

                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                                    Task {
                                        try? await AuthService.shared.signInWithApple(credential: credential)
                                    }
                                }
                            case .failure(let error):
                                authVM.error = error.localizedDescription
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)

                        // Forgot password
                        if mode == .signIn {
                            Button("Forgot password?") {
                                showReset = true
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color("Accent"))
                        }

                        // Validation hint
                        if mode == .signUp && !formValid && !email.isEmpty {
                            validationHint
                        }

                        Spacer(minLength: 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
              }
              .safeAreaInset(edge: .bottom) {
                  EmptyView().frame(height: 0)
              }
          }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert("Reset Password", isPresented: $showReset) {
            TextField("Email", text: $email)
            Button("Send Reset Link") {
                Task { await authVM.resetPassword(email: email) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your email to receive a password reset link.")
        }
    }

    // ── Validation hint ───────────────────────────────────────

    @ViewBuilder
    private var validationHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !email.contains("@") {
                Label("Valid email required", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            if password.count < 6 {
                Label("Password must be at least 6 characters", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            if !confirmPassword.isEmpty && password != confirmPassword {
                Label("Passwords don't match", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            if displayName.isEmpty {
                Label("Name is required", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
        .padding(.horizontal)
    }

    // ── Helpers ───────────────────────────────────────────────

    private var formValid: Bool {
        let emailOK = email.contains("@")
        let passOK  = password.count >= 6
        if mode == .signUp {
            return emailOK && passOK && password == confirmPassword && !displayName.isEmpty
        }
        return emailOK && passOK
    }

    private func primaryAction() async {
        isLoading = true
        if mode == .signIn {
            await authVM.signIn(email: email, password: password)
        } else {
            await authVM.signUp(email: email, password: password, displayName: displayName)
        }
        isLoading = false
    }
}

// ── AuthField ─────────────────────────────────────────────────

struct AuthField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var contentType: UITextContentType = .username
    var keyboard: UIKeyboardType = .default
    var isSecure = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(contentType)
            } else {
                TextField(placeholder, text: $text)
                    .textContentType(contentType)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(
                        keyboard == .emailAddress ? .never : .words
                    )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
