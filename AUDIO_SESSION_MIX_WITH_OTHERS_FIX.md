# Audio Session `.mixWithOthers` Fix - Attempt to Share Mic Access

## The Problem

iOS CallKit blocks WKWebView's `getUserMedia()` from accessing the microphone, even with explicit user interaction.

**Root Cause**: CallKit's audio session uses exclusive microphone access by default, preventing other contexts (like WKWebView) from accessing the mic simultaneously.

---

## The Solution: `.mixWithOthers` Option

Added `.mixWithOthers` to all `AVAudioSession.setCategory()` calls.

### What `.mixWithOthers` Does:

**From Apple Docs:**
> "An option that indicates whether audio from this session mixes with audio from active sessions in other audio apps."

**Theory**: If CallKit's audio session allows "mixing," iOS might permit WKWebView's `getUserMedia()` to share microphone access.

---

## Implementation

### Modified Files:

#### 1. **VoiceCallSession.swift**
All audio session configurations now include `.mixWithOthers`:

```swift
// Before:
try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])

// After:
try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .mixWithOthers])
```

**Changed in:**
- `ensureAudioSessionActive()` - Multiple locations
- `setAudioOutput()` - Earpiece and speaker modes
- `playRingtone()` - Ringtone playback
- `forceEarpieceAudio()` - Route changes
- All audio session setup points

#### 2. **CallKitManager.swift**
CallKit's audio session activation now includes `.mixWithOthers`:

```swift
// Before:
try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])

// After:
try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
```

**Changed in:**
- `provider(_:didActivate:)` - When CallKit activates audio
- `configureAudioSession()` - Manual audio setup

---

## Expected Behavior

### If `.mixWithOthers` Works:

1. **Call connects** via CallKit
2. **Audio session activates** with `.mixWithOthers`
3. **WebView calls `getUserMedia()`** 
4. **iOS allows access** because session is "mixable"
5. **Track is `muted=false`** ✅
6. **Microphone works immediately!** ✅
7. **No user tap required!** ✅

### Testing Logs to Look For:

```
✅ [CallKit] Audio session configured: playAndRecord + voiceChat mode
🌐 [WebRTC-JS] ✅ [WebRTC] Track 0: muted=false  ← KEY INDICATOR!
✅ [VoiceCallScreen] WebRTC peer connection established
[NO overlay should appear]
[Android should hear iOS audio immediately]
```

---

## If It Doesn't Work

If track is still `muted=true` even with `.mixWithOthers`, this confirms that iOS's restriction is **absolute** and we must implement:

### **Plan B: Native Audio Bridge**

1. Capture mic in native Swift using `AVAudioEngine`
2. Send audio buffers to JavaScript via WKWebView bridge
3. Use Web Audio API to inject into WebRTC
4. Replace track in peer connection

**Complexity**: High  
**Development Time**: 3-4 hours  
**Success Rate**: Very high (proven approach)

---

## Testing Steps

1. **Make call from Android to iOS**
2. **Accept on iOS** (lock screen/notification)
3. **Watch for key log:**
   ```
   🌐 [WebRTC-JS] ✅ [WebRTC] Track 0: muted=???
   ```
4. **If `muted=false`:**
   - ✅ Speak into iPhone
   - ✅ Ask Android if they can hear you
   - ✅ **SUCCESS! No more fixes needed!**

5. **If `muted=true`:**
   - ❌ Still blocked by iOS
   - ❌ Proceed to Plan B (Native Audio Bridge)

---

## Why This Might Work

### Audio Session Hierarchy:

iOS has complex audio session priority rules:

1. **Phone calls** (highest priority)
2. **CallKit** (very high priority)  
3. **VoIP apps** (high priority)
4. **Media playback** (medium priority)
5. **Background audio** (low priority)

By default, CallKit uses **exclusive mode** - only CallKit can access mic.

With `.mixWithOthers`:
- CallKit says "I'm willing to share"
- Other contexts (WKWebView) can request access
- iOS might allow both to coexist

**Precedent**: Apps like Discord use `.mixWithOthers` to allow background music while on voice calls.

---

## Alternative We Tried (Failed)

### What Didn't Work:
1. ❌ Skip AudioContext for iOS
2. ❌ Re-request getUserMedia() after remote audio plays
3. ❌ Remove silent audio wake attempts  
4. ❌ Explicit user tap prompt
5. ❌ All automatic workarounds

### Why:
iOS treats WKWebView and CallKit as separate "apps" and blocks mic sharing by default, regardless of JavaScript-level tricks.

---

## Why `.mixWithOthers` Is Different

**This is the first time we're changing the NATIVE audio session configuration to explicitly allow sharing.**

All previous attempts worked at the JavaScript/WebView level. This works at the **iOS system level** where the actual blocking occurs.

---

## Success Criteria

**Full Success**: `muted=false` immediately, mic works, no overlay needed.

**Partial Success**: Track becomes unmuted after small delay.

**Failure**: Track remains `muted=true`, overlay still appears.

---

## Files Modified

- `Enclosure/VoiceCall/VoiceCallSession.swift` (8 locations)
- `Enclosure/Utility/CallKitManager.swift` (2 locations)

---

## Next Steps

### If Successful:
1. Remove overlay prompt code (no longer needed)
2. Clean up unused muted track detection
3. Celebrate! 🎉

### If Unsuccessful:
1. Implement native audio bridge (Plan B)
2. Keep `.mixWithOthers` (doesn't hurt, might help other scenarios)
3. Document final solution

---

**Test this NOW and report results!** 🎤🔧

Look for **one key log line**:
```
🌐 [WebRTC-JS] ✅ [WebRTC] Track 0: muted=false
```

**If you see this, WE WON!** ✅
