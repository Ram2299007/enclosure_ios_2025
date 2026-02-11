# 🔑 Setup Your APNs Key - Step by Step

## ✅ What You Have

- **Key ID:** `838GP97CYN`
- **Key Name:** Enclosure APNs Key
- **Services:** APNs ✅
- **Environment:** Sandbox & Production ✅

---

## 📋 What You Need to Complete Setup

### 1️⃣ Get Your Team ID (2 minutes)

1. Go to https://developer.apple.com/account
2. Click your name (top right) → **Membership** or **Account**
3. Copy your **Team ID** (looks like `ABCD123456`)
   
   Example:
   ```
   Team ID: XYZ9876543
   ```

---

### 2️⃣ Get Your Private Key (2 minutes)

#### If You Already Downloaded It:

Find your `AuthKey_838GP97CYN.p8` file on your computer.

#### If You Haven't Downloaded It Yet:

1. Click on **"Enclosure APNs Key"** in the Keys list
2. Click **"Download"** button
3. Save `AuthKey_838GP97CYN.p8` file

⚠️ **CRITICAL:** You can only download this ONCE! If you lose it, you must create a new key.

#### Open the .p8 File:

1. Open `AuthKey_838GP97CYN.p8` in TextEdit (Mac) or any text editor
2. You'll see something like:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgYour+actual+key+
content+goes+here+with+many+lines+of+base64+encoded+data+that+looks+
like+random+characters+but+is+actually+your+private+cryptographic+key
-----END PRIVATE KEY-----
```

3. **Copy the ENTIRE content** (including BEGIN/END lines)

---

### 3️⃣ Update iOS Code (5 minutes)

**File:** `Enclosure/Utility/MessageUploadService.swift`

**Find the `createAPNsJWT()` method (around line 1103) and replace with:**

```swift
private func createAPNsJWT() -> String? {
    let keyId = "838GP97CYN"  // ✅ Your Key ID
    let teamId = "YOUR_TEAM_ID_HERE"  // ⚠️ PASTE your Team ID here
    let privateKey = """
    -----BEGIN PRIVATE KEY-----
    PASTE_YOUR_PRIVATE_KEY_CONTENT_HERE
    -----END PRIVATE KEY-----
    """
    
    // Rest of implementation from APNS_JWT_IMPLEMENTATION.swift
    // ...
}
```

**OR** use the complete implementation from `APNS_JWT_IMPLEMENTATION.swift` file I created.

---

### 4️⃣ Update Android Backend Code (5 minutes)

**File:** `FcmNotificationsSender.java`

**Find the `createAPNsJWT()` method (around line 285) and replace with:**

```java
private String createAPNsJWT() {
    String keyId = "838GP97CYN";  // ✅ Your Key ID
    String teamId = "YOUR_TEAM_ID_HERE";  // ⚠️ PASTE your Team ID here
    String privateKey = 
        "-----BEGIN PRIVATE KEY-----\n" +
        "PASTE_YOUR_PRIVATE_KEY_CONTENT_HERE\n" +
        "-----END PRIVATE KEY-----";
    
    // Rest of implementation from APNS_JWT_IMPLEMENTATION.java
    // ...
}
```

**OR** use the complete implementation from `APNS_JWT_IMPLEMENTATION.java` file I created.

---

## 🎯 Quick Setup Checklist

- [ ] Get Team ID from Apple Developer Portal
- [ ] Locate or download `AuthKey_838GP97CYN.p8` file
- [ ] Open .p8 file and copy private key content
- [ ] Update iOS `MessageUploadService.swift` with Team ID and private key
- [ ] Update Android `FcmNotificationsSender.java` with Team ID and private key
- [ ] Build and run iOS app
- [ ] Test call notification in background
- [ ] Check logs for "✅ [VOIP] VoIP Push sent SUCCESSFULLY!"

---

## 🧪 Testing After Setup

### Step 1: Check JWT Creation

**Build iOS app and check logs:**

```
🔑 [APNs JWT] Creating JWT token...
🔑 [APNs JWT] Key ID: 838GP97CYN
🔑 [APNs JWT] Team ID: YOUR_TEAM_ID
✅ [APNs JWT] JWT token created successfully!
🔑 [APNs JWT] Token: eyJhbGciOiJFUzI1NiIsImtpZCI6IjgzOEdQOTdDW...
```

### Step 2: Test Background Call

1. Put iOS app in **background** (press home button)
2. Send call from Android device
3. **Check backend logs:**

```
📞 [VOIP] Detected CALL notification for iOS!
📞 [VOIP] Sending VoIP Push to APNs...
✅ [VOIP] VoIP Push sent SUCCESSFULLY!
```

4. **Check iOS - Should see:**

```
🎉 INSTANT FULL-SCREEN CALLKIT!
```

No banner! No tap needed! Just instant CallKit! ✅

---

## ⚠️ Troubleshooting

### Error: "Team ID not configured"

**Problem:** You forgot to replace `YOUR_TEAM_ID_HERE`

**Solution:** Go to Apple Developer → Membership, copy your Team ID

---

### Error: "Private key not configured"

**Problem:** You forgot to paste the private key content

**Solution:** Open `AuthKey_838GP97CYN.p8` file, copy everything, paste it

---

### Error: "403 Forbidden" from APNs

**Problem:** JWT token is invalid

**Possible causes:**
- Wrong Team ID
- Wrong Key ID (should be `838GP97CYN`)
- Corrupted private key
- Key was revoked

**Solution:** Double-check all values, regenerate JWT token

---

### Error: "410 Device Token Invalid"

**Problem:** VoIP token is wrong or expired

**Solution:** 
- Make sure iOS app registered VoIP token
- Check database has correct VoIP token
- Test with fresh app install

---

## 📚 Reference Files

I created these files for you:

1. **`APNS_JWT_IMPLEMENTATION.swift`** - Complete iOS JWT implementation
2. **`APNS_JWT_IMPLEMENTATION.java`** - Complete Android JWT implementation
3. **`TODO_VOIP_IMPLEMENTATION.md`** - Complete TODO checklist

---

## 🎯 Final Step

Once you've updated both files with your Team ID and private key:

1. **Rebuild iOS app**
2. **Restart Android backend** (if needed)
3. **Test background call**
4. **Celebrate when instant CallKit appears!** 🎉

---

## 💡 Quick Copy Template

```
Key ID: 838GP97CYN
Team ID: [PASTE YOUR TEAM ID HERE]
Private Key: [PASTE CONTENT FROM AuthKey_838GP97CYN.p8 HERE]
```

---

**You're almost there! Just need to paste 2 values and you're done!** 🚀
