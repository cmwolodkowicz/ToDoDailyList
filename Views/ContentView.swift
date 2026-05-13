import SwiftUI
import Auth

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
        @StateObject private var todoVM = TodoViewModel()
        @State private var selectedTab = 0
        @State private var sharedDate = DateUtils.today()  // ADD THIS

        var body: some View {
            TabView(selection: $selectedTab) {
                DailyListView(sharedDate: $sharedDate)  // UPDATE THIS
                    .environmentObject(todoVM)
                    .tabItem { Label("Today", systemImage: "list.bullet") }
                    .tag(0)

                CalendarView(selectedTab: $selectedTab, sharedDate: $sharedDate)  // UPDATE THIS
                    .environmentObject(todoVM)
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                    .tag(1)

                HistoryView()
                    .environmentObject(todoVM)
                    .tabItem { Label("History", systemImage: "clock") }
                    .tag(2)

                SettingsView()
                    .environmentObject(authVM)
                    .environmentObject(todoVM)
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(3)
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
