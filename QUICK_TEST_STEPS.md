# 🧪 Quick Test Steps - CallKit VoIP

## Your files ARE in the project! Just need to rebuild.

### Step 1: Clean Build Folder

**In Xcode:**
- Press **Command + Shift + K** (Product → Clean Build Folder)
- Wait for "Clean Finished"

### Step 2: Build Project

- Press **Command + B** (Product → Build)
- Wait for "Build Succeeded"

### Step 3: Run on Device

- Press **Command + R** (Product → Run)
- App launches on iPhone

### Step 4: Open Debug Console

- Press **Command + Shift + Y**
- You'll see console at bottom with `(lldb)` prompt

### Step 5: Type Test Command

After `(lldb)` prompt, type:
```lldb
expr VoIPTestHelper.testVoIPPushReceived()
```

Press **Enter**

### Step 6: Continue Execution

- Click **Continue** button (▶️) in debug toolbar
- OR press **Control + Command + Y**

---

## 🎉 Expected Result

**On your iPhone:**
- Full-screen CallKit UI appears
- Shows "Test Caller (VoIP)"
- Answer/Decline buttons
- Just like WhatsApp!

**In Console:**
```
🧪 [TEST] Simulating VoIP Push Received
📞 [TEST] Triggering CallKit...
✅ [TEST] CallKit SUCCESS!
```

---

## 🆘 If It Still Doesn't Work

### Error: "Cannot find VoIPTestHelper"

**Solution:** Quit Xcode completely and reopen:
1. Quit Xcode (Command + Q)
2. Reopen Xcode
3. Open your project
4. Clean Build (Command + Shift + K)
5. Build (Command + B)
6. Run (Command + R)
7. Try LLDB command again

### Error: "Use of unresolved identifier"

**Solution:** Check if files are visible in Xcode:
1. In Xcode, press Command + Shift + O (Open Quickly)
2. Type: `VoIPTestHelper`
3. If file appears in list → Files are added ✅
4. If nothing appears → Need to restart Xcode

---

## 🔄 Alternative: Test Button in UI

Want an easier way? I can add a test button in your app!

Tell me which screen and I'll add:
```swift
Button("🧪 Test CallKit") {
    VoIPTestHelper.testVoIPPushReceived()
}
```

Tap button → CallKit appears! No LLDB needed!

---

## 📸 Your Screenshot Shows

Your Finder screenshot shows files exist at:
```
✅ VoIPPushManager.swift
✅ VoIPTestHelper.swift
```

Since your Xcode project uses automatic sync, these files ARE in the project!

**Just need to Clean Build and Run!**

Press these keys in Xcode:
1. **Command + Shift + K** (Clean)
2. **Command + B** (Build)
3. **Command + R** (Run)

Then try the LLDB test command! 🚀
