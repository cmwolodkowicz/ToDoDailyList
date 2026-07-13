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

//                HistoryView()
//                    .environmentObject(todoVM)
//                    .tabItem { Label("History", systemImage: "clock") }
//                    .tag(2)

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
            print("DEBUG: Task started, currentUser: \(String(describing: authVM.currentUser?.id))")
            var attempts = 0
            while authVM.currentUser == nil && attempts < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                attempts += 1
                print("DEBUG: Waiting for auth, attempt \(attempts), currentUser: \(String(describing: authVM.currentUser?.id))")
            }
            
            if let userId = authVM.currentUser?.id {
                print("DEBUG: Calling bootstrap with userId: \(userId)")
                await todoVM.bootstrap(userId: userId)
            } else {
                print("DEBUG: No user found after waiting, bootstrap not called")
            }
        }
        .onChange(of: authVM.currentUser) { _, newUser in
            print("DEBUG: onChange triggered, newUser: \(String(describing: newUser?.id))")
            if let userId = newUser?.id, todoVM.items.isEmpty {
                print("DEBUG: Calling bootstrap from onChange")
                Task { await todoVM.bootstrap(userId: userId) }
            } else if newUser == nil {
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
