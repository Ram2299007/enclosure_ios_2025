# TODO: Get CallKit Working

## The Problem
You're seeing **normal notification banners** instead of **full-screen CallKit UI**

## The Fix (2 Steps)

### Step 1: Add CallKitManager.swift to Xcode ⚠️ REQUIRED!

The file exists but is NOT in your Xcode project yet!

**How to Add**:
1. Open `Enclosure.xcodeproj` in Xcode
2. Find `Enclosure/Utility/CallKitManager.swift` in file system (Finder)
3. **Drag and drop** it into Xcode's `Enclosure/Utility` folder
4. In dialog that appears:
   - ✅ Check "Copy items if needed"
   - ✅ Check "Enclosure" target
   - Click "Add"
5. Build the project (Cmd+B)

**OR use menu**:
1. Right-click `Enclosure/Utility` folder in Xcode
2. Choose "Add Files to Enclosure..."
3. Select `CallKitManager.swift`
4. Ensure target is checked
5. Click "Add"

### Step 2: Rebuild Android App

The Android code has been updated to send data-only notifications for iOS (no banner).

**How to Rebuild**:
1. Open Android Studio
2. Build → Clean Project
3. Build → Rebuild Project
4. Install on your Android device
5. Test call again

## After Both Steps

**Android will send**:
- Data-only push (no notification banner)
- `content-available: 1` to wake iOS app
- `category: VOICE_CALL` for CallKit

**iOS will show**:
- Full-screen native call UI (NOT a banner!)
- Circular caller photo on left
- App icon on right
- Accept and Decline buttons

## Quick Test

After adding CallKitManager and rebuilding both apps:

```
Android Device → Send Call → iOS Device
                              ↓
                    📱 Full-Screen Call UI Appears!
                    
                    [Photo]  Priti Lohar  [Icon]
                    
                         Enclosure
                    
                    🔴 Decline    Accept 🟢
```

## Why It's Not Working Now

1. ❌ CallKitManager.swift exists as a file but is NOT compiled into the app
2. ❌ Android is still sending old payload (with notification banner)

After fixing both:
✅ iOS receives silent data-only push
✅ AppDelegate triggers CallKit
✅ CallKit shows full-screen UI
✅ No notification banner!

## Verify It's Working

**Console should show**:
```
📱 [FCM] bodyKey = Incoming voice call
📞 [CallKit] Voice/Video call notification received
📞 [CallKit] Caller: Priti Lohar
✅ [CallKit] Successfully reported incoming call
```

**Screen should show**:
- Full-screen call UI (NOT a banner at top)
- Caller photo and name
- Accept/Decline buttons

## Important Notes

⚠️ **Test on REAL device** - CallKit doesn't work fully in iOS Simulator
⚠️ **File must be in Xcode project** - Just creating the file is not enough
⚠️ **Both apps must be rebuilt** - Android and iOS need the new code

Good luck! 🚀
