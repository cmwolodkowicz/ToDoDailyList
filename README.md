# DailyList — iOS App Setup Guide

A full-featured daily to-do list app built with SwiftUI + Supabase.

---

## File Structure

```
DailyList/
├── App/
│   └── DailyListApp.swift          # App entry point, scene setup
├── Models/
│   ├── TodoItem.swift              # Core data model + enums
│   └── UserProfile.swift          # User settings model
├── ViewModels/
│   ├── AuthViewModel.swift         # Auth state + actions
│   └── TodoViewModel.swift         # All to-do business logic
├── Services/
│   ├── SupabaseService.swift       # Supabase client config
│   ├── AuthService.swift           # Auth operations
│   └── TodoService.swift           # CRUD + realtime
├── Views/
│   ├── ContentView.swift           # Root tab view
│   ├── DailyListView.swift         # Main list screen
│   ├── HistoryView.swift           # Past lists browser
│   ├── AuthView.swift              # Login / sign up
│   ├── SettingsView.swift          # Profile + notifications
│   ├── SplashView.swift            # Launch screen
│   ├── Components/
│   │   └── TodoRow.swift           # Individual list item row
│   └── Sheets/
│       ├── ItemFormView.swift      # Add / edit item sheet
│       ├── RolloverView.swift      # Morning leftover prompt
│       └── MoveDateSheet.swift     # Pick a date to move item
├── Notifications/
│   └── NotificationService.swift  # APNs scheduling
├── Utilities/
│   └── DateUtils.swift            # Date helpers + recurrence logic
└── Resources/
    └── supabase_schema.sql        # Run this in Supabase SQL Editor
```

---

## Step 1 — Create the Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Settings:
   - **Product Name:** `DailyList`
   - **Team:** Your Apple Developer account
   - **Bundle Identifier:** `com.yourname.dailylist` (must be unique)
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None (Supabase handles this)
4. Click **Next**, choose a save location, **Create**

---

## Step 2 — Add the Supabase Swift SDK

1. In Xcode: **File → Add Package Dependencies**
2. Paste this URL: `https://github.com/supabase/supabase-swift`
3. Set version rule: **Up to Next Major → 2.0.0**
4. Click **Add Package**
5. When prompted, add both **Supabase** and **Auth** to your target

---

## Step 3 — Set Up Supabase

### 3a. Create a project
1. Go to [supabase.com](https://supabase.com) → **New Project**
2. Name it `dailylist`, choose a region, set a strong database password
3. Wait ~2 minutes for the project to provision

### 3b. Run the database schema
1. In Supabase Dashboard → **SQL Editor** → **New Query**
2. Copy the entire contents of `Resources/supabase_schema.sql`
3. Paste and click **Run**
4. You should see "Success" with no errors

### 3c. Enable Auth providers
1. Dashboard → **Authentication → Providers**
2. **Email** — should be enabled by default. Confirm email is optional for testing (disable "Confirm email" under Email settings)
3. **Apple** — toggle on. You'll need:
   - Apple Services ID (created in Apple Developer portal)
   - Apple Team ID
   - Key ID + private key (.p8 file) from Apple Developer portal
   - See: https://supabase.com/docs/guides/auth/social-login/auth-apple

### 3d. Get your API credentials
1. Dashboard → **Project Settings → API**
2. Copy:
   - **Project URL** (looks like `https://abcdefgh.supabase.co`)
   - **anon / public** key (the long JWT string)

---

## Step 4 — Configure the App

Open `Services/SupabaseService.swift` and replace the placeholders:

```swift
enum SupabaseConfig {
    static let url     = URL(string: "https://YOUR_PROJECT_REF.supabase.co")!
    static let anonKey = "YOUR_ANON_KEY"
}
```

---

## Step 5 — Add Files to Xcode

1. In Xcode's Project Navigator, **delete** the auto-generated `ContentView.swift` (move to trash)
2. For each `.swift` file in this project:
   - Right-click the appropriate group folder in Project Navigator
   - **Add Files to "DailyList"** → select the file
   - Make sure **"Copy items if needed"** is checked and your app target is selected
3. Create the folder groups to match the structure above (right-click → New Group)

**Tip:** You can also drag all files at once into the Project Navigator.

---

## Step 6 — Add the Accent Color

1. In Xcode, open `Assets.xcassets`
2. Click **+** → **New Color Set**
3. Name it exactly `Accent`
4. Set the color to a warm amber/orange: `#F59E0B` (or any color you like)
5. Set a dark mode variant if desired

---

## Step 7 — Configure Push Notifications

1. In Xcode → Click your project → **Signing & Capabilities**
2. Click **+ Capability** → add **Push Notifications**
3. Also add **Background Modes** → check **Remote notifications**
4. In Supabase Dashboard → **Project Settings → API** → note your `service_role` key
5. For production push, you'll configure APNs keys in Supabase Dashboard → **Settings → Auth → Push**

> **Note:** Local notifications (reminders, daily reminder) work without any extra setup. APNs is only needed for server-triggered push in the future.

---

## Step 8 — Sign In with Apple Entitlement

1. Xcode → **Signing & Capabilities → + Capability → Sign In with Apple**
2. In Apple Developer Portal → **Certificates, IDs & Profiles → Identifiers**
3. Find your App ID → enable **Sign In with Apple**
4. Create a **Services ID** for Supabase callback URL
5. Follow Supabase's Apple auth guide: https://supabase.com/docs/guides/auth/social-login/auth-apple

---

## Step 9 — Info.plist Entries

Add these to your `Info.plist` (or via Xcode's target Info tab):

```xml
<!-- Required for magic link / OAuth deep linking -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.yourname.dailylist</string>
        </array>
    </dict>
</array>
```

In Supabase Dashboard → **Authentication → URL Configuration**:
- **Site URL:** `com.yourname.dailylist://`
- **Redirect URLs:** add `com.yourname.dailylist://`

---

## Step 10 — Build and Run

1. Select a simulator (iPhone 15 recommended) or your physical device
2. **Cmd+R** to build and run
3. Create an account, add your first to-do item!

---

## App Store Submission Checklist

When you're ready to ship:

- [ ] Set a real **Bundle ID** and **version number**
- [ ] Add an **App Icon** set in `Assets.xcassets`
- [ ] Create a **Launch Screen** storyboard or use the default
- [ ] Enable **Confirm Email** in Supabase Auth settings
- [ ] Test Sign In with Apple on a real device (doesn't work in simulator)
- [ ] Set up **APNs** keys in Supabase for reliable push delivery
- [ ] Review Apple's [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [ ] If you offer Sign In with Apple, it must be listed first among sign-in options ✓ (already done)
- [ ] Archive → **Product → Archive** → Distribute App → App Store Connect

---

## Supabase Free Tier Limits (as of 2024)

- **Database:** 500 MB
- **Auth users:** Unlimited
- **Realtime:** 200 concurrent connections
- **API requests:** 2 million/month

More than enough to get started and share with friends!

---

## Troubleshooting

**Build errors about missing Supabase module:**
→ Make sure you added the Swift package (Step 2) and your target is checked

**"No data returned" errors:**
→ Check that RLS policies were created — re-run the SQL schema

**Realtime not updating:**
→ Confirm `supabase_realtime` publication was added (last line of schema SQL)

**Sign In with Apple not showing:**
→ Must test on a real device with an Apple ID signed in; won't work in simulator

**App crashes on launch:**
→ Check that `Accent` color exists in `Assets.xcassets` exactly as named
