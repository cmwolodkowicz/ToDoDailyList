import SwiftUI
import Auth

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var todoVM: TodoViewModel
    @State private var profile: UserProfile?
    @State private var displayName = ""
    @State private var dailyReminderEnabled = true
    @State private var dailyReminderTime = Date()
    @State private var showSignOutConfirm = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                // ── Profile ──────────────────────────────────
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color("Accent"))
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Your name", text: $displayName)
                                .font(.headline)
                            Text(authVM.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── Notifications ────────────────────────────
                Section("Notifications") {
                    Toggle("Daily Reminder", isOn: $dailyReminderEnabled)

                    if dailyReminderEnabled {
                        DatePicker("Reminder Time",
                                   selection: $dailyReminderTime,
                                   displayedComponents: .hourAndMinute)
                        .onChange(of: dailyReminderTime) { _, newVal in
                            let fmt = DateFormatter()
                            fmt.dateFormat = "HH:mm"
                            NotificationService.shared.scheduleDailyReminder(time: fmt.string(from: newVal))
                        }
                    }
                }

                // ── Save ─────────────────────────────────────
                Section {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save Changes").fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .foregroundStyle(Color("Accent"))
                    .disabled(isSaving)
                }

                // ── Account ──────────────────────────────────
                Section("Account") {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // ── App info ─────────────────────────────────
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                }
            }
            .navigationTitle("Settings")
            .onAppear { prefill() }
            .confirmationDialog("Sign out of DailyList?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await authVM.signOut() }
                }
            }
        }
    }

    private func prefill() {
        guard let p = authVM.profile else { return }
        profile = p
        displayName = p.displayName ?? ""
        dailyReminderEnabled = p.dailyReminderEnabled

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        if let d = fmt.date(from: p.dailyReminderTime) {
            dailyReminderTime = d
        }
    }

    private func saveProfile() async {
        guard var p = authVM.profile else { return }
        isSaving = true

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        p.displayName = displayName.isEmpty ? nil : displayName
        p.dailyReminderEnabled = dailyReminderEnabled
        p.dailyReminderTime = fmt.string(from: dailyReminderTime)

        await authVM.updateProfile(p)

        if dailyReminderEnabled {
            NotificationService.shared.scheduleDailyReminder(time: p.dailyReminderTime)
        } else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
        }

        isSaving = false
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
