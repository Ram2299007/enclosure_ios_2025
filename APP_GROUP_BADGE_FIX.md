# App Group Badge Count Fix

## Problem
```swift
// ❌ Error in NotificationService.swift
let currentBadge = UIApplication.shared.applicationIconBadgeNumber
// Error: 'shared' is unavailable in application extensions for iOS
```

**Issue:** Notification Service Extension cannot access `UIApplication.shared` because extensions don't have access to UIApplication.

---

## Solution: Use App Group

### What is App Group?
App Groups allow data sharing between your main app and extensions (like Notification Service Extension).

### Implementation

#### 1. Badge Count Storage
Instead of directly accessing `UIApplication.shared.applicationIconBadgeNumber`, we:
1. Store badge count in **App Group UserDefaults**
2. Read from App Group in both app and extension
3. Sync badge count between app and extension

#### 2. Code Changes

**In NotificationService.swift (Extension):**
```swift
// ✅ Use App Group UserDefaults
let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data")
let currentBadge = sharedDefaults?.integer(forKey: "badgeCount") ?? 0
let newBadge = currentBadge + 1

// Store updated count
sharedDefaults?.set(newBadge, forKey: "badgeCount")

// Set badge in notification
bestAttemptContent.badge = NSNumber(value: newBadge)
```

**In BadgeManager.swift (Main App):**
```swift
private let appGroupID = "group.com.enclosure.data"
private let badgeCountKey = "badgeCount"

private var sharedDefaults: UserDefaults? {
    return UserDefaults(suiteName: appGroupID)
}

func setBadgeCount(_ count: Int) {
    // Set in UIApplication (main app only)
    UIApplication.shared.applicationIconBadgeNumber = count
    
    // Store in App Group (accessible by extension)
    sharedDefaults?.set(count, forKey: badgeCountKey)
}
```

---

## How It Works

### Scenario 1: New Notification Arrives (App Closed)
```
1. Notification arrives → NotificationService runs
2. Extension reads badge from App Group: badgeCount = 3
3. Extension increments: newBadge = 4
4. Extension stores in App Group: badgeCount = 4
5. Extension sets notification.badge = 4
6. iOS displays notification with badge 4
7. User sees "4" on app icon ✅
```

### Scenario 2: User Opens App
```
1. App becomes active
2. BadgeManager.syncBadgeWithNotificationCenter() called
3. Reads delivered notifications: count = 4
4. Reads App Group: badgeCount = 4
5. Uses max(count, badgeCount) = 4
6. Sets UIApplication.shared.applicationIconBadgeNumber = 4
7. Updates App Group: badgeCount = 4 ✅
```

### Scenario 3: User Opens Chat
```
1. User taps chat with 2 unread messages
2. BadgeManager.decrementBadge(by: 2) called
3. Current badge = 4
4. New badge = 4 - 2 = 2
5. Sets UIApplication.shared.applicationIconBadgeNumber = 2
6. Updates App Group: badgeCount = 2 ✅
```

---

## App Group Setup (Already Done)

### 1. Xcode Configuration
Your app already has App Group configured:
- **App Group ID:** `group.com.enclosure.data`
- **Enabled in:**
  - Main App (Enclosure)
  - Notification Service Extension
  - Notification Content Extension

### 2. Entitlements Files

**Enclosure.entitlements:**
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.enclosure.data</string>
</array>
```

**EnclosureNotificationService.entitlements:**
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.enclosure.data</string>
</array>
```

✅ Already configured - no changes needed!

---

## Key Differences

### ❌ Before (Incorrect)
```swift
// In NotificationService.swift
let currentBadge = UIApplication.shared.applicationIconBadgeNumber
// Error: unavailable in extensions
```

### ✅ After (Correct)
```swift
// In NotificationService.swift
let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data")
let currentBadge = sharedDefaults?.integer(forKey: "badgeCount") ?? 0
// Works in extensions! ✅
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────┐
│                    App Group Storage                     │
│          UserDefaults("group.com.enclosure.data")       │
│                  Key: "badgeCount" = 5                  │
└─────────────────────────────────────────────────────────┘
           ↑                                    ↑
           │ Write                              │ Write
           │                                    │
    ┌──────┴────────┐                  ┌───────┴─────────┐
    │  Main App     │                  │  Notification   │
    │               │                  │  Service Ext    │
    │ BadgeManager  │                  │                 │
    │ - setBadge()  │                  │ - didReceive()  │
    │ - sync()      │                  │ - increment()   │
    └───────────────┘                  └─────────────────┘
           │                                    
           │ Read/Write                         
           ↓                                    
    ┌──────────────────┐                       
    │  UIApplication   │                       
    │  .shared         │                       
    │  .badgeNumber    │                       
    │  (Main App Only) │                       
    └──────────────────┘                       
```

---

## Testing

### Verify App Group Works

1. **Send Notification:**
   - App in background
   - Send notification from backend
   - Check Console logs:
   ```
   📱 [NotificationService] Badge updated (App Group): 3 -> 4
   ```

2. **Check Storage:**
   ```swift
   // In main app
   let stored = UserDefaults(suiteName: "group.com.enclosure.data")?
                .integer(forKey: "badgeCount")
   print("Stored badge count: \(stored)")
   ```

3. **Verify Sync:**
   - Kill app
   - Send 3 notifications
   - Open app
   - Badge should show "3" ✅

---

## Benefits

### ✅ Extension Compatible
- No `UIApplication.shared` usage in extensions
- Works in Notification Service Extension
- No compiler errors

### ✅ Accurate Counting
- Badge count persists across app launches
- Syncs between app and extensions
- No lost counts

### ✅ Clean Architecture
- Centralized badge management
- App Group as single source of truth
- Easy to debug

---

## Summary

**Problem:** `UIApplication.shared` unavailable in Notification Service Extension

**Solution:** Use App Group UserDefaults to share badge count

**Files Changed:**
1. `NotificationService.swift` - Read/write badge from App Group
2. `BadgeManager.swift` - Store badge in App Group when updating

**Result:** Badge count works perfectly in both app and extension! ✅

---

## मराठीत:

**समस्या:** Extension मध्ये `UIApplication.shared` वापरता येत नाही

**उपाय:** App Group वापरून badge count share करा

**काय केलं:**
1. Notification Extension badge count App Group मध्ये store करतो
2. Main app App Group मधून badge वाचतो
3. दोन्ही sync मध्ये राहतात

**Result:** Badge counting मस्त काम करते! 🎉
