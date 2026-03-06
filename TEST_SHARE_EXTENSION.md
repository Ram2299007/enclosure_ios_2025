# How to Test Share Extension - Text Sharing

## Quick Test Steps

### Method 1: Basic Test (Recommended)

1. **Build and Run the Main App**
   - In Xcode, select **"Enclosure"** scheme
   - Build and run (⌘R) on a device or simulator
   - Make sure the app launches successfully

2. **Share Text from an External App**
   - Open **Safari** (or Notes, Messages, etc.)
   - Select some text or copy text
   - Tap the **Share** button
   - Look for **"Enclosure"** in the share sheet
   - Tap **"Enclosure"**

3. **Expected Behavior**
   - Share Extension should process the text
   - Main app should open automatically
   - `ShareExternalDataContactScreen` should appear
   - You should see a list of contacts to share with

### Method 2: Test with Console Logs

1. **Attach Share Extension Debugger**
   - Run the main app first
   - In Xcode: **Debug** → **Attach to Process by PID or Name...**
   - Type: `EnclosureShareExtension`
   - Click **Attach**

2. **Share Text**
   - Open Safari/Notes
   - Select text → Share → Tap "Enclosure"

3. **Check Xcode Console**
   - You should see logs like:
     ```
     🔴🔴🔴 [ShareExtension] beginRequest CALLED
     📤 [ShareExtension] Text-only share - saving immediately
     📤 [ShareExtension] Opening main app with URL: enclosure://share
     ```

4. **Check Main App Console**
   - You should see:
     ```
     📤 [MainActivityOld] Received HandleSharedContent notification
     📤 [MainActivityOld] Found shared content type: text
     📤 [MainActivityOld] Setting showShareExternalDataContactScreen = true
     ```

### Method 3: Use Console.app (macOS) - Most Reliable

1. **Open Console.app** on your Mac
   - Applications → Utilities → Console

2. **Connect Device/Simulator**
   - If using physical device, connect via USB
   - Console.app should detect it automatically

3. **Filter Logs**
   - In search box (top right), type: `EnclosureShareExtension`
   - Clear existing logs to see only new ones

4. **Test Sharing**
   - On device: Open Safari → Select text → Share → Tap "Enclosure"
   - Watch Console.app immediately

5. **What to Look For**
   ```
   🔴🔴🔴 [ShareExtension] beginRequest CALLED
   📤 [ShareExtension] Found X extension items
   📤 [ShareExtension] Text-only share - saving immediately
   📤 [ShareExtension] Successfully saved shared content to file
   📤 [ShareExtension] Opening main app with URL: enclosure://share
   ```

## Testing Different Text Sources

### Test 1: Safari (Web Text)
1. Open Safari
2. Navigate to any webpage
3. Select text on the page
4. Tap Share → Enclosure
5. ✅ Should open contact selection screen

### Test 2: Notes App
1. Open Notes
2. Create or open a note with text
3. Select text
4. Tap Share → Enclosure
5. ✅ Should open contact selection screen

### Test 3: Messages App
1. Open Messages
2. Open any conversation
3. Long-press a message → Copy
4. Go to any app → Share → Enclosure
5. ✅ Should open contact selection screen

### Test 4: Plain Text File
1. Open Files app
2. Create/open a .txt file
3. Share → Enclosure
5. ✅ Should open contact selection screen

## What to Verify

### ✅ Success Indicators:
1. **Share Extension Processes Text**
   - Logs show text data being saved
   - No errors in console

2. **Main App Opens**
   - App automatically opens after sharing
   - No manual app launch needed

3. **Contact Screen Appears**
   - `ShareExternalDataContactScreen` is visible
   - Shows list of contacts
   - Search bar is functional

4. **Text Data is Available**
   - When you select a contact and tap "Share"
   - Text should be sent to the contact
   - Check the chat to verify message was sent

### ❌ Failure Indicators:
1. **Share Extension Doesn't Appear**
   - "Enclosure" not in share sheet
   - Check: Info.plist configuration

2. **Share Extension Crashes**
   - Check crash logs in Xcode
   - Window → Devices and Simulators → View Device Logs

3. **Text Not Detected**
   - Logs show "No attachments and no text"
   - Check: Text extraction logic

4. **Main App Doesn't Open**
   - Share Extension completes but app doesn't open
   - Check: URL scheme registration in Info.plist

5. **Contact Screen Doesn't Appear**
   - App opens but wrong screen shows
   - Check: Notification handling in MainActivityOld

## Debug Checklist

If something doesn't work, check:

- [ ] Share Extension target builds without errors
- [ ] Main app target builds without errors
- [ ] App Group is configured: `group.com.enclosure`
- [ ] URL scheme is registered: `enclosure://share`
- [ ] Share Extension appears in share sheet
- [ ] Console logs show Share Extension running
- [ ] Console logs show main app receiving notification
- [ ] Shared content file is created in App Group container
- [ ] `checkForSharedContent()` finds the shared data
- [ ] `showShareExternalDataContactScreen` is set to `true`

## Common Issues & Solutions

### Issue: "Enclosure" doesn't appear in share sheet
**Solution:**
- Check Info.plist has correct NSExtension configuration
- Rebuild and reinstall the app
- Restart device/simulator

### Issue: Share Extension crashes immediately
**Solution:**
- Check crash logs in Xcode
- Verify code signing is correct
- Check for missing frameworks

### Issue: Text not detected
**Solution:**
- Check console logs for text extraction
- Verify plain text attachment loading works
- Test with different text sources

### Issue: Main app doesn't open
**Solution:**
- Verify URL scheme is registered in main app's Info.plist
- Check `EnclosureApp.swift` handles the URL correctly
- Verify notification is posted

### Issue: Contact screen doesn't appear
**Solution:**
- Check `MainActivityOld` receives notification
- Verify `checkForSharedContent()` finds the data
- Check `showShareExternalDataContactScreen` state variable
- Verify `.fullScreenCover` modifier is in place

## Advanced Testing

### Test with Breakpoints

1. **Add Breakpoint in ShareViewController**
   - Open `ShareViewController.swift`
   - Add breakpoint at line 218 (saveAndOpenApp call)
   - Run app → Share text → Breakpoint should hit

2. **Add Breakpoint in MainActivityOld**
   - Open `MainActivityOld.swift`
   - Add breakpoint at line 1398 (showShareExternalDataContactScreen = true)
   - Run app → Share text → Breakpoint should hit

### Test App Group Data

1. **Check Shared File**
   - After sharing, check if file exists:
   - App Group container: `group.com.enclosure/sharedContent.json`
   - Use FileManager to verify file exists

2. **Check UserDefaults**
   - After sharing, check UserDefaults:
   ```swift
   let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure")
   let contentType = sharedDefaults?.string(forKey: "sharedContentType")
   let textData = sharedDefaults?.string(forKey: "sharedTextData")
   ```

## Expected Log Flow

### Share Extension Logs:
```
🔴🔴🔴 [ShareExtension] beginRequest CALLED
📤 [ShareExtension] Found 1 extension items
📤 [ShareExtension] Text-only share - saving immediately
📤 [ShareExtension] textData: Your shared text here...
📤 [ShareExtension] Successfully saved shared content to file
📤 [ShareExtension] Opening main app with URL: enclosure://share
✅ [ShareExtension] Successfully opened main app with URL scheme
```

### Main App Logs:
```
📤 [AppDelegate] application(_:open:options:) CALLED
📤 [AppDelegate] ✅ URL matches enclosure://share - posting notification
📤 [MainActivityOld] Received HandleSharedContent notification
📤 [MainActivityOld] Checking for shared content...
📤 [MainActivityOld] Found shared content file
📤 [MainActivityOld] ✅ Successfully read from file container
📤 [MainActivityOld] Found text: Your shared text here...
📤 [MainActivityOld] Setting showShareExternalDataContactScreen = true
✅ [MainActivityOld] ShareExternalDataContactScreen appeared!
```

## Success Criteria

✅ **Test is successful if:**
1. Share Extension appears in share sheet
2. Text is detected and saved
3. Main app opens automatically
4. Contact selection screen appears
5. You can select contacts and share the text
6. Text message is sent successfully

If all these work, your share extension is functioning correctly! 🎉
