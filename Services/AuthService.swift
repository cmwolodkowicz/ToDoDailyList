import Foundation
import Supabase
import AuthenticationServices

final class AuthService {
    static let shared = AuthService()
    private let auth = SupabaseService.shared.client.auth

    // ── Current session ──────────────────────────────────────

    var currentUserId: UUID? {
        get async {
            try? await auth.session.user.id
        }
    }

    // ── Email / Password ─────────────────────────────────────

    func signUp(email: String, password: String, displayName: String) async throws {
        let metadata: [String: AnyJSON] = ["display_name": .string(displayName)]
        try await auth.signUp(
            email: email,
            password: password,
            data: metadata
        )
    }

    func signIn(email: String, password: String) async throws {
        try await auth.signIn(email: email, password: password)
    }

    func resetPassword(email: String) async throws {
        try await auth.resetPasswordForEmail(email)
    }

    // ── Sign in with Apple ───────────────────────────────────

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.invalidAppleCredential
        }
        let nonce = ""  // handled internally by Supabase Swift SDK
        try await auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: token, nonce: nonce)
        )
    }

    // ── Sign out ─────────────────────────────────────────────

    func signOut() async throws {
        try await auth.signOut()
    }

    // ── Auth state stream ────────────────────────────────────

    var authStateChanges: AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in
            Task {
                for await (event, _) in await auth.authStateChanges {
                    continuation.yield(event)
                }
            }
        }
    }

    // ── User profile ─────────────────────────────────────────

    func fetchProfile(userId: UUID) async throws -> UserProfile {
        let profile: UserProfile = try await SupabaseService.shared.client
            .from("user_profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        return profile
    }

    func upsertProfile(_ profile: UserProfile) async throws {
        try await SupabaseService.shared.client
            .from("user_profiles")
            .upsert(profile)
            .execute()
    }
}

enum AuthError: LocalizedError {
    case invalidAppleCredential

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential: return "Could not retrieve Apple ID token."
        }
    }
}
