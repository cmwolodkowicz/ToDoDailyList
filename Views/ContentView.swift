import SwiftUI
import Auth

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var todoVM = TodoViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DailyListView()
                .environmentObject(todoVM)
                .tabItem { Label("Today", systemImage: "list.bullet") }
                .tag(0)

            HistoryView()
                .environmentObject(todoVM)
                .tabItem { Label("History", systemImage: "calendar") }
                .tag(1)

            SettingsView()
                .environmentObject(authVM)
                .environmentObject(todoVM)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(2)
        }
        .tint(Color("Accent"))
        .sheet(isPresented: $todoVM.showRollover) {
            RolloverView()
                .environmentObject(todoVM)
        }
        .task {
            if let userId = authVM.currentUser?.id {
                await todoVM.bootstrap(userId: userId)
            }
        }
        .onChange(of: authVM.currentUser) { _, newUser in
            if newUser == nil {
                todoVM.cleanup()
            }
        }
        .alert("Error", isPresented: .constant(todoVM.error != nil)) {
            Button("OK") { todoVM.error = nil }
        } message: {
            Text(todoVM.error ?? "")
        }
    }
}
