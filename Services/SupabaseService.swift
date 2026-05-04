import Foundation
import Supabase

// ─────────────────────────────────────────────────────────────
// MARK: - Configuration
// Replace these values with your Supabase project credentials.
// Found in: Supabase Dashboard → Project Settings → API
// ─────────────────────────────────────────────────────────────
enum SupabaseConfig {
    static let url        = URL(string: Secrets.supabaseURL)!
    static let anonKey    = Secrets.supabaseAnonKey
}

final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }

    func handleOpenURL(_ url: URL) async {
        await client.auth.handle(url)
    }
}
