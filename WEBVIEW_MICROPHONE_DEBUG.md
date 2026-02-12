# WebView Microphone Debugging Enhancements

## Issue
Microphone not starting when accepting calls - Android side cannot hear the iOS user even though:
- Audio session is active (✅ logs show "Audio session activated")
- Microphone is available (✅ logs show "Input available: true")
- Input ports are correct (✅ logs show "MicrophoneBuiltIn")

This suggests the issue is at the **WebView/WebRTC layer** - the native audio session is working but WebRTC isn't capturing the microphone.

## Changes Made

### 1. Enhanced WebView Configuration
**File:** `Enclosure/VoiceCall/VoiceCallWebView.swift`

```swift
// Added configurations for better getUserMedia() support
configuration.allowsPictureInPictureMediaPlayback = true
if #available(iOS 14.3, *) {
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true
}
```

**Why:** Ensures JavaScript can execute getUserMedia() and WebRTC APIs properly.

### 2. Enhanced Media Capture Permission Logging (iOS 15+)
```swift
@available(iOS 15.0, *)
func webView(_ webView: WKWebView,
             requestMediaCapturePermissionFor origin: WKSecurityOrigin,
             initiatedByFrame frame: WKFrameInfo,
             type: WKMediaCaptureType,
             decisionHandler: @escaping (WKPermissionDecision) -> Void) {
    NSLog("🎤🎤🎤 [VoiceCallWebView] ========================================")
    NSLog("🎤 [VoiceCallWebView] Media capture permission requested (iOS 15+)")
    NSLog("🎤 [VoiceCallWebView] Type: \(type.rawValue)")
    NSLog("🎤 [VoiceCallWebView] GRANTING permission")
    NSLog("🎤🎤🎤 [VoiceCallWebView] ========================================")
    decisionHandler(.grant)
}
```

**Why:** Confirms WebView is actually requesting microphone access and we're granting it.

### 3. Page Load Success Check
```swift
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    NSLog("📱 [VoiceCallWebView] Page loaded successfully")
    
    // Check Android bridge
    webView.evaluateJavaScript("typeof Android !== 'undefined'") { result, error in
        if let isAvailable = result as? Bool, isAvailable {
            NSLog("✅ [VoiceCallWebView] Android bridge available")
        }
    }
    
    // Check getUserMedia() availability
    webView.evaluateJavaScript("typeof navigator.mediaDevices.getUserMedia !== 'undefined'") { result, error in
        if let isAvailable = result as? Bool, isAvailable {
            NSLog("✅✅✅ [VoiceCallWebView] getUserMedia() available - microphone can be captured")
        } else {
            NSLog("❌ [VoiceCallWebView] getUserMedia() NOT available - microphone won't work!")
        }
    }
    
    // Check if microphone is muted
    webView.evaluateJavaScript("window.Android.getMuteState()") { result, error in
        if let isMuted = result as? Bool, isMuted {
            NSLog("⚠️⚠️⚠️ [VoiceCallWebView] MICROPHONE IS MUTED!")
        } else {
            NSLog("✅ [VoiceCallWebView] Microphone is NOT muted")
        }
    }
}
```

**Why:** Verifies:
1. WebView loaded successfully
2. JavaScript bridge works
3. getUserMedia() API is available
4. Microphone isn't muted in WebRTC

### 4. Page Load Failure Check
```swift
func webView(_ webView: WKWebView,
             didFail navigation: WKNavigation!,
             withError error: Error) {
    NSLog("❌ [VoiceCallWebView] Page load failed: \(error.localizedDescription)")
}
```

**Why:** Catches if indexVoice.html fails to load, which would prevent WebRTC from initializing.

## Expected Logs After Fix

### Successful Flow
```
🎤 [VoiceCallWebView] WebView created with microphone permissions
📱 [VoiceCallWebView] Page loaded successfully
✅ [VoiceCallWebView] Android bridge available
✅✅✅ [VoiceCallWebView] getUserMedia() available - microphone can be captured
✅ [VoiceCallWebView] Microphone is NOT muted
🎤 [VoiceCallWebView] Media capture permission requested (iOS 15+)
🎤 [VoiceCallWebView] Type: microphone
🎤 [VoiceCallWebView] GRANTING permission
```

### If Microphone Fails
Look for one of these in logs:

1. **getUserMedia() not available:**
   ```
   ❌ [VoiceCallWebView] getUserMedia() NOT available - microphone won't work!
   ```
   **Fix:** Update indexVoice.html to polyfill getUserMedia()

2. **Microphone muted:**
   ```
   ⚠️⚠️⚠️ [VoiceCallWebView] MICROPHONE IS MUTED!
   ```
   **Fix:** Unmute microphone in JavaScript or check mute button state

3. **Page load failed:**
   ```
   ❌ [VoiceCallWebView] Page load failed: [error]
   ```
   **Fix:** Check if indexVoice.html exists in bundle

4. **No permission request:**
   - If you DON'T see "Media capture permission requested", WebRTC isn't calling getUserMedia()
   - **Fix:** Check JavaScript code in indexVoice.html

## Debugging Checklist

### Check These Logs in Order:

1. **WebView creation:**
   - [ ] See: "🎤 [VoiceCallWebView] WebView created with microphone permissions"

2. **Page load:**
   - [ ] See: "📱 [VoiceCallWebView] Page loaded successfully"
   - [ ] NOT see: "❌ [VoiceCallWebView] Page load failed"

3. **Android bridge:**
   - [ ] See: "✅ [VoiceCallWebView] Android bridge available"
   - [ ] NOT see: "⚠️ [VoiceCallWebView] Android bridge not found"

4. **getUserMedia() support:**
   - [ ] See: "✅✅✅ [VoiceCallWebView] getUserMedia() available"
   - [ ] NOT see: "❌ [VoiceCallWebView] getUserMedia() NOT available"

5. **Mute state:**
   - [ ] See: "✅ [VoiceCallWebView] Microphone is NOT muted"
   - [ ] NOT see: "⚠️⚠️⚠️ [VoiceCallWebView] MICROPHONE IS MUTED!"

6. **Permission request (iOS 15+):**
   - [ ] See: "🎤 [VoiceCallWebView] Media capture permission requested"
   - [ ] See: "🎤 [VoiceCallWebView] GRANTING permission"

### If All Checks Pass But Still No Audio

The issue might be in:
1. **WebRTC stream configuration** - Check JavaScript console in indexVoice.html
2. **PeerJS connection** - Check if peer connection is established
3. **Audio track not sent** - Check if local audio track is added to peer connection
4. **Android receiving side** - Check if Android can receive audio streams

## Common Issues and Solutions

### Issue 1: getUserMedia() Returns Undefined
**Cause:** WebView security restrictions or HTTP context (needs HTTPS or localhost)

**Solution:**
- Ensure indexVoice.html is loaded from file:// URL
- Check that mediaDevices API is supported in WebView
- Verify iOS version (getUserMedia() requires iOS 14.3+)

### Issue 2: Permission Request Never Fires
**Cause:** JavaScript isn't calling getUserMedia()

**Solution:**
- Check indexVoice.html JavaScript initialization
- Look for console errors in WebRTC initialization
- Verify PeerJS is creating local media stream

### Issue 3: Microphone Always Muted
**Cause:** Default mute state or mute button state persisted

**Solution:**
- Check UserDefaults for "voice_call_muted" key
- Clear app data to reset mute state
- Check if UI mute button is toggled

### Issue 4: Works on Lock Screen, Not Foreground
**Cause:** Different audio session lifecycle in foreground

**Solution:**
- Already implemented delay in checkMicrophonePermission()
- Multiple activation attempts should handle this
- Check logs for audio session activation timing

## Testing Commands

### Check in Xcode Console After Accepting Call:

```bash
# Should see these logs in order:
1. "🎤 [VoiceCallWebView] WebView created"
2. "📱 [VoiceCallWebView] Page loaded successfully"
3. "✅ [VoiceCallWebView] Android bridge available"
4. "✅✅✅ [VoiceCallWebView] getUserMedia() available"
5. "✅ [VoiceCallWebView] Microphone is NOT muted"
6. "🎤 [VoiceCallWebView] Media capture permission requested"
7. "✅ [VoiceCallSession] Audio session activated"
8. "🎤 [VoiceCallSession] - Input available: true"
```

### If Any Step Fails, Note Which One
The failed step will indicate exactly where the microphone capture is breaking.

## Next Steps If Issue Persists

If all logs show success but microphone still doesn't work, check:

1. **JavaScript console** - Safari Web Inspector on indexVoice.html
2. **WebRTC internals** - Check if local media stream has audio tracks
3. **PeerJS connection** - Verify peer connection has outgoing audio
4. **Network** - Check if WebRTC packets are being sent
5. **Android receiver** - Verify Android can receive and play audio streams

## iOS Version Compatibility

- **iOS 15.0+:** Full support with `requestMediaCapturePermissionFor`
- **iOS 14.3+:** getUserMedia() available but uses older permission model
- **iOS 14.0-14.2:** Limited WebRTC support
- **iOS 13.x:** May require polyfills

Current implementation supports iOS 14.3+ properly.
