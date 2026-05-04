import SwiftUI

@main
struct DailyListApp: App {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var notificationService = NotificationService.shared

    init() {
        NotificationService.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isLoading {
                    SplashView()
                } else if authVM.currentUser != nil {
                    ContentView()
                        .environmentObject(authVM)
                        .environmentObject(notificationService)
                } else {
                    AuthView()
                        .environmentObject(authVM)
                }
            }
            .onOpenURL { url in
                // Handle deep links (e.g. magic link auth)
                Task { await SupabaseService.shared.handleOpenURL(url) }
            }
        }
    }
}
