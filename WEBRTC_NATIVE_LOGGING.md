# WebRTC Native Logging Bridge

## Issue
JavaScript console logs showing WebRTC audio track status weren't visible in Xcode console, making it impossible to debug why the microphone isn't sending audio to Android.

## Solution

### 1. Added `logToNative()` Bridge Function
**File:** `Enclosure/VoiceCall/VoiceCallWebView.swift`

Added new bridge method that allows JavaScript to send logs to native iOS:

```swift
window.Android = {
  logToNative: function(message) {
    try { 
      window.webkit.messageHandlers.voiceCall.postMessage({
        type: 'logToNative', 
        message: message
      }); 
    } catch (e) {}
  },
  // ... other methods
};
```

### 2. Added Native Log Handler
**File:** `Enclosure/VoiceCall/VoiceCallSession.swift`

Added handler to receive and log JavaScript messages:

```swift
case "logToNative":
    if let logMessage = message["message"] as? String {
        NSLog("🌐 [WebRTC-JS] %@", logMessage)
        print("🌐 [WebRTC-JS] \(logMessage)")
    }
```

### 3. Updated JavaScript to Log to Native
**File:** `Enclosure/VoiceCallAssets/scriptVoice.js`

Modified `markConnectedIfNeeded()` to send WebRTC diagnostics to native:

```javascript
// Log to both console AND native iOS
if (typeof Android !== 'undefined' && Android.logToNative) {
    Android.logToNative('🎤 [WebRTC] Call connected - diagnosing microphone');
    Android.logToNative(`🎤 [WebRTC] Local stream: ${localStream ? 'EXISTS' : 'MISSING'}`);
    Android.logToNative(`🎤 [WebRTC] Audio tracks: ${audioTracks.length}`);
    
    // For each audio track
    Android.logToNative(`🎤 [WebRTC] Track 0: enabled=${track.enabled}, state=${track.readyState}, muted=${track.muted}`);
    
    // Check if track has problems
    if (!track.enabled) {
        Android.logToNative(`❌ [WebRTC] Track is DISABLED!`);
    }
    if (track.readyState !== 'live') {
        Android.logToNative(`❌ [WebRTC] Track state is ${track.readyState} (should be 'live')`);
    }
    if (track.muted) {
        Android.logToNative(`❌ [WebRTC] Track is MUTED at WebRTC level!`);
    }
    
    // For peer connection senders
    Android.logToNative(`🎤 [WebRTC] Peer ${peerId}: ${senders.length} senders`);
    Android.logToNative(`🎤 [WebRTC] Sender 0: kind=${sender.track.kind}, enabled=${sender.track.enabled}`);
}
```

## Expected Logs in Xcode Console

### Successful WebRTC Audio
```
✅✅✅ [VoiceCallScreen] CALL CONNECTED!
🌐 [WebRTC-JS] 🎤 [WebRTC] ========================================
🌐 [WebRTC-JS] 🎤 [WebRTC] Call connected - diagnosing microphone
🌐 [WebRTC-JS] 🎤 [WebRTC] Local stream: EXISTS
🌐 [WebRTC-JS] 🎤 [WebRTC] Audio tracks: 1
🌐 [WebRTC-JS] 🎤 [WebRTC] Track 0: enabled=true, state=live, muted=false
🌐 [WebRTC-JS] 🎤 [WebRTC] Peer [id]: 1 senders
🌐 [WebRTC-JS] 🎤 [WebRTC] Sender 0: kind=audio, enabled=true, state=live
🌐 [WebRTC-JS] 🎤 [WebRTC] ========================================
```

### If Local Stream Missing
```
🌐 [WebRTC-JS] ❌❌❌ [WebRTC] NO LOCAL STREAM - getUserMedia() not called or failed!
```

### If Track Disabled
```
🌐 [WebRTC-JS] 🎤 [WebRTC] Track 0: enabled=false, state=live, muted=false
🌐 [WebRTC-JS] ❌ [WebRTC] Track is DISABLED!
```

### If Track Ended
```
🌐 [WebRTC-JS] 🎤 [WebRTC] Track 0: enabled=true, state=ended, muted=false
🌐 [WebRTC-JS] ❌ [WebRTC] Track state is ended (should be 'live')
```

### If Track Muted at WebRTC Level
```
🌐 [WebRTC-JS] 🎤 [WebRTC] Track 0: enabled=true, state=live, muted=true
🌐 [WebRTC-JS] ❌ [WebRTC] Track is MUTED at WebRTC level!
```

### If No Senders
```
🌐 [WebRTC-JS] 🎤 [WebRTC] Peer [id]: 0 senders
🌐 [WebRTC-JS] ⚠️ [WebRTC] NO AUDIO BEING SENT TO PEER!
```

## How It Works

### JavaScript → Native Bridge
1. JavaScript code executes diagnostic checks
2. Calls `Android.logToNative("message")`
3. Message sent to native via `window.webkit.messageHandlers.voiceCall`
4. Native receives message with type `"logToNative"`
5. `VoiceCallSession.handleMessage()` processes it
6. Logs appear in Xcode console with `🌐 [WebRTC-JS]` prefix

### Dual Logging
Logs appear in **both** places:
- **JavaScript console** (Safari Web Inspector)
- **Xcode console** (via logToNative bridge) ← **New!**

## Why This is Critical

### Before This Change
- WebRTC logs only in JavaScript console
- Required Safari Web Inspector to debug
- User couldn't easily see WebRTC state

### After This Change
- WebRTC logs in Xcode console ✅
- No Safari Web Inspector needed ✅
- Can diagnose from Xcode directly ✅

## Diagnostic Scenarios

### Scenario 1: Local Stream Not Created
```
🌐 [WebRTC-JS] ❌❌❌ [WebRTC] NO LOCAL STREAM
```
**Cause:** `navigator.mediaDevices.getUserMedia()` never called or failed
**Fix:** Check JavaScript initialization, ensure getUserMedia() is called

### Scenario 2: Track Exists but Disabled
```
🌐 [WebRTC-JS] 🎤 [WebRTC] Track 0: enabled=false
🌐 [WebRTC-JS] ❌ [WebRTC] Track is DISABLED!
```
**Cause:** Track was disabled after creation (maybe by mute logic)
**Fix:** Check mute state logic, ensure track.enabled = true

### Scenario 3: Track Ended Prematurely
```
🌐 [WebRTC-JS] 🎤 [WebRTC] Track 0: enabled=true, state=ended
🌐 [WebRTC-JS] ❌ [WebRTC] Track state is ended (should be 'live')
```
**Cause:** Track was stopped or media device disconnected
**Fix:** Reinitialize getUserMedia(), check for track.stop() calls

### Scenario 4: Track Muted at WebRTC Level
```
🌐 [WebRTC-JS] 🎤 [WebRTC] Track 0: enabled=true, state=live, muted=true
🌐 [WebRTC-JS] ❌ [WebRTC] Track is MUTED at WebRTC level!
```
**Cause:** Browser muted track (different from track.enabled)
**Fix:** Check browser audio settings, ensure track.muted = false

### Scenario 5: Track Not Added to Peer Connection
```
🌐 [WebRTC-JS] 🎤 [WebRTC] Peer [id]: 0 senders
```
**Cause:** Audio track not added to RTCPeerConnection
**Fix:** Ensure `peer.call(peerId, localStream)` is called with valid stream

### Scenario 6: Sender Has No Track
```
🌐 [WebRTC-JS] ⚠️ [WebRTC] Sender 0 has NO TRACK!
```
**Cause:** RTCRtpSender exists but has no media track attached
**Fix:** Check if track was removed, ensure `addTrack()` completed

## Testing Instructions

### For User:
1. Accept a call from Android
2. Wait for "CALL CONNECTED!" in Xcode logs
3. **Look for new logs starting with `🌐 [WebRTC-JS]`**
4. Share those logs to diagnose the issue

### What We'll Learn:
The logs will show **exactly** which of these is the problem:
- ❌ Local stream doesn't exist
- ❌ Audio track disabled
- ❌ Audio track ended/stopped
- ❌ Audio track muted at WebRTC level
- ❌ No senders (track not added to peer)
- ❌ Sender has no track

Once we see the logs, we'll know the exact fix needed!

## Benefits

✅ **WebRTC diagnostics in Xcode** - No Safari Web Inspector needed
✅ **Real-time debugging** - See WebRTC state as call connects
✅ **Clear error messages** - Shows exactly what's wrong
✅ **Easy troubleshooting** - Logs point to specific fix
✅ **Dual logging** - Available in both console and Xcode

## Next Steps

After getting the WebRTC diagnostic logs, we'll be able to:
1. Identify exact WebRTC issue
2. Apply targeted fix
3. Verify microphone audio is sent to Android
