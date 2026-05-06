import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var profile: UserProfile?
    @Published var isLoading = true
    @Published var error: String?

    private let service = AuthService.shared

    init() {
        Task { await observeAuthState() }
    }

    // ── Auth state listener ──────────────────────────────────

    private func observeAuthState() async {
        isLoading = true
        
        do {
            let session = try await SupabaseService.shared.client.auth.session
            await MainActor.run {
                currentUser = session.user
            }
            await loadProfile(userId: session.user.id)
        } catch {
            // No existing session
        }
        
        await MainActor.run {
            isLoading = false
        }

        for await event in service.authStateChanges {
            switch event {
            case .signedIn:
                if let session = try? await SupabaseService.shared.client.auth.session {
                    await MainActor.run {
                        currentUser = session.user
                    }
                    await loadProfile(userId: session.user.id)
                }
            case .signedOut:
                await MainActor.run {
                    currentUser = nil
                    profile = nil
                    isLoading = false
                }
            default:
                break
            }
        }
    }

    private func loadProfile(userId: UUID) async {
        do {
            profile = try await service.fetchProfile(userId: userId)
        } catch {
            // First login — create default profile
            let newProfile = UserProfile.defaultProfile(
                id: userId,
                email: currentUser?.email
            )
            try? await service.upsertProfile(newProfile)
            profile = newProfile
        }
    }

    // ── Sign Up ──────────────────────────────────────────────

    func signUp(email: String, password: String, displayName: String) async {
        error = nil
        do {
            try await service.signUp(email: email, password: password, displayName: displayName)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // ── Sign In ──────────────────────────────────────────────

    func signIn(email: String, password: String) async {
        error = nil
        do {
            try await service.signIn(email: email, password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // ── Sign In with Apple ───────────────────────────────────

    func signInWithApple() async {
        error = nil
        // Handled via AppleSignInButton → AuthView
    }

    // ── Sign Out ─────────────────────────────────────────────

    func signOut() async {
        do {
            try await service.signOut()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // ── Reset Password ───────────────────────────────────────

    func resetPassword(email: String) async {
        error = nil
        do {
            try await service.resetPassword(email: email)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // ── Profile update ───────────────────────────────────────

    func updateProfile(_ updated: UserProfile) async {
        do {
            try await service.upsertProfile(updated)
            profile = updated
        } catch {
            self.error = error.localizedDescription
        }
    }
}
