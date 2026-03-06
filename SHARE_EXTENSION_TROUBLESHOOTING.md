# Share Extension Troubleshooting Guide

## Current Issue: Share Extension Not Opening ShareExternalDataScreen

### Symptoms:
- App opens MainActivityOld when sharing from Photos
- No Share Extension logs in console
- ShareExternalDataScreen never appears

## Step-by-Step Diagnosis

### 1. Verify Share Extension Appears in Share Sheet

**Test:**
1. Open Photos app
2. Select an image
3. Tap Share button
4. **Look for "Enclosure" in the share sheet**

**If "Enclosure" is NOT visible:**
- The Share Extension target might not be built/installed
- Go to Xcode → Product → Scheme → Select "EnclosureShareExtension"
- Build and Run the Share Extension target at least once
- Then build and run the main app
- Restart device/simulator

**If "Enclosure" IS visible but nothing happens:**
- Continue to step 2

### 2. Check App Group Configuration

**In Xcode:**
1. Select **Enclosure** target
2. Go to **Signing & Capabilities**
3. Look for **App Groups** capability
4. Verify `group.com.enclosure` is listed

5. Select **EnclosureShareExtension** target
6. Go to **Signing & Capabilities**
7. Look for **App Groups** capability
8. Verify `group.com.enclosure` is listed (same ID)

**If App Groups is missing:**
- Click **+ Capability** → **App Groups**
- Add: `group.com.enclosure`
- Do this for BOTH targets

**If App Groups exists but UserDefaults returns nil:**
- Both targets must be signed with the same Team
- Clean Build Folder (Shift+Cmd+K)
- Rebuild both targets

### 3. Check Console Logs

**When you share an image, you should see:**

**From Share Extension:**
```
📤 [ShareExtension] viewDidLoad called
✅ [ShareExtension] App Group UserDefaults accessible
📤 [ShareExtension] Saving shared content...
✅ [ShareExtension] Verified saved content type: image
📤 [ShareExtension] Opening main app with URL: enclosure://share
```

**From Main App:**
```
📤 [MainActivityOld] Received HandleSharedContent notification
📤 [MainActivityOld] Checking for shared content...
📤 [MainActivityOld] App Group UserDefaults accessible: ✅
📤 [MainActivityOld] Found shared content type: image
📤 [MainActivityOld] ====== SHARED CONTENT READY ======
📤 [MainActivityOld] Setting showShareExternalDataScreen = true
✅ [MainActivityOld] ShareExternalDataScreen appeared!
```

**If you see NO Share Extension logs:**
- Share Extension is not running
- Check step 1 (Extension not appearing in share sheet)
- Check if Share Extension target builds without errors

**If you see "App Group UserDefaults is nil":**
- App Group is not configured (see step 2)
- Check entitlements files exist and have correct group ID

**If you see "No shared content found":**
- Share Extension didn't save data
- Check Share Extension logs for errors
- Verify App Group is shared between Extension and App

### 4. Verify Entitlements Files

**Check these files exist:**
- `Enclosure/Enclosure.entitlements` - Should have App Groups
- `EnclosureShareExtension/EnclosureShareExtension.entitlements` - Should have App Groups

**Content should include:**
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.enclosure</string>
</array>
```

### 5. Manual Test (Debug Build)

**To test if screen presentation works:**
1. Add this temporary code in `MainActivityOld.onAppear`:
```swift
// TEMP TEST - Remove after testing
DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
    var testContent = SharedContent(type: .text)
    testContent.textData = "Test"
    self.sharedContentToShow = testContent
    self.showShareExternalDataScreen = true
}
```

2. Run the app
3. Wait 2 seconds
4. If ShareExternalDataScreen appears → Screen presentation works, issue is with Share Extension
5. If ShareExternalDataScreen doesn't appear → Screen presentation issue

### 6. Common Issues and Solutions

**Issue: "Enclosure" doesn't appear in share sheet**
- Solution: Build Share Extension target, restart device

**Issue: App Group UserDefaults returns nil**
- Solution: Configure App Groups capability in Xcode for both targets

**Issue: Share Extension crashes immediately**
- Solution: Check Share Extension logs, verify Info.plist is correct

**Issue: Data saved but screen doesn't appear**
- Solution: Check if `showShareExternalDataScreen` is being set to true (check logs)
- Verify `sharedContentToShow` is not nil

**Issue: Screen appears but is blank**
- Solution: Check if `SharedContent` is properly initialized
- Verify image/video URLs are valid file paths

## Next Steps

1. **First:** Verify Share Extension appears in share sheet (Step 1)
2. **Second:** Configure App Groups if missing (Step 2)
3. **Third:** Check console logs when sharing (Step 3)
4. **Fourth:** Share the console output so we can diagnose further

## Quick Fix Checklist

- [ ] Share Extension target built at least once
- [ ] App Groups capability added to Enclosure target
- [ ] App Groups capability added to EnclosureShareExtension target
- [ ] Both targets use same App Group ID: `group.com.enclosure`
- [ ] Both targets signed with same Team
- [ ] Clean Build Folder performed
- [ ] Device/Simulator restarted
- [ ] Share Extension appears in share sheet
- [ ] Console logs show Share Extension running
