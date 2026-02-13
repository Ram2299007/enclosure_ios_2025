# Fix: Foreground Microphone Muted Issue

## Problem Summary

**Lockscreen acceptance:** Microphone works perfectly ✅
- Track shows: `muted=false`
- Android can hear iOS user

**Foreground acceptance:** Microphone not working ❌
- Track shows: `muted=true`
- Android cannot hear iOS user

## Root Cause Analysis

### What Was Happening

1. **Lockscreen (WORKING):**
   ```
   User accepts call
   ↓
   CallKit activates audio session
   ↓
   CallKitManager.didActivate(audioSession:) configures .mixWithOthers
   ↓
   Natural delay (unlocking, UI animation) ~1-2 seconds
   ↓
   VoiceCallSession.start() → WebRTC connects
   ↓
   getUserMedia() → Microphone ready → muted=false ✅
   ```

2. **Foreground (NOT WORKING):**
   ```
   User accepts call
   ↓
   CallKit activates audio session
   ↓
   CallKitManager.didActivate(audioSession:) starts configuring...
   ↓
   BUT IMMEDIATELY: VoiceCallSession.start() → WebRTC connects ⚡️ TOO FAST!
   ↓
   getUserMedia() called BEFORE audio session fully configured
   ↓
   Microphone captured but muted=true ❌
   ```

### The Critical Timing Issue

The `.mixWithOthers` audio session option is **CRITICAL** for WKWebView's `getUserMedia()` to access the microphone. Without it, the WebView can create the audio track but it will be **muted**.

In lockscreen, there's a natural delay (unlock animation, Face ID, etc.) that gives CallKit time to fully configure the audio session.

In foreground, there's **NO delay** - the app is already active, so WebRTC tries to connect **immediately**, racing with CallKit's audio configuration.

## The Solution

### Flag + Notification-Based Synchronization

We added a **persistent flag + notification system** to **ensure CallKit's audio session is fully ready** before WebRTC tries to access the microphone:

**Why both flag AND notification?**
- Notification handles normal case (observer set up before audio ready)
- Flag handles race condition (audio ready before observer set up)

#### 1. CallKitManager Sets Flag AND Posts Notification

```swift
// Add persistent flag
private(set) var isAudioSessionReady = false

func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    // Configure audio session with critical .mixWithOthers option
    try audioSession.setCategory(.playAndRecord, mode: .voiceChat, 
                                options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
    
    // CRITICAL: Set flag (for race condition) AND post notification
    isAudioSessionReady = true
    NotificationCenter.default.post(name: NSNotification.Name("CallKitAudioSessionReady"), 
                                   object: nil)
}

func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    isAudioSessionReady = false  // Reset when call ends
}
```

#### 2. VoiceCallSession Checks Flag THEN Waits for Notification

```swift
func start() {
    if !payload.isSender {  // Incoming CallKit call
        // CRITICAL: Check flag first (handles race condition)
        if CallKitManager.shared.isAudioSessionReady {
            NSLog("✅✅✅ CallKit audio ALREADY READY - proceeding immediately!")
            proceedWithStart()
            return
        }
        
        // Audio not ready yet - wait for notification
        callKitAudioReadyObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CallKitAudioSessionReady"),
            ...
        ) { [weak self] _ in
            // NOW it's safe to start WebRTC
            self?.proceedWithStart()
        }
        
        // Timeout fallback after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self?.proceedWithStart()
        }
    } else {  // Outgoing call
        // No wait needed - we manage audio ourselves
        proceedWithStart()
    }
}
```

## Flow After Fix

### Foreground Acceptance (NOW WORKING)

```
User accepts call in foreground
↓
CallKit activates audio session
↓
VoiceCallSession.start() called
↓
VoiceCallSession WAITS for "CallKitAudioSessionReady" notification
↓
CallKitManager.didActivate() configures .mixWithOthers
↓
Posts "CallKitAudioSessionReady" notification
↓
VoiceCallSession receives notification → proceedWithStart()
↓
WebRTC connects with FULLY configured audio session
↓
getUserMedia() → muted=false ✅ WORKING!
```

### Lockscreen Acceptance (STILL WORKING)

```
User accepts call on lockscreen
↓
CallKit activates audio session
↓
VoiceCallSession.start() called
↓
VoiceCallSession WAITS for "CallKitAudioSessionReady" notification
↓
CallKitManager.didActivate() configures .mixWithOthers
↓
Posts notification → VoiceCallSession proceeds
↓
WebRTC connects → muted=false ✅ WORKING!
```

## Key Changes Made

### CallKitManager.swift

**Added persistent flag + notification:**
```swift
// New property
private(set) var isAudioSessionReady = false

// In didActivate
isAudioSessionReady = true
NotificationCenter.default.post(name: NSNotification.Name("CallKitAudioSessionReady"), object: nil)

// In didDeactivate
isAudioSessionReady = false

// In endCall
if activeCalls.isEmpty {
    isAudioSessionReady = false
}
```

### VoiceCallSession.swift

**Added flag check + notification synchronization:**
1. New properties: `callKitAudioReadyObserver` and `isWaitingForCallKitAudio`
2. `start()` method **checks flag first**, then waits for notification if needed
3. New `proceedWithStart()` method contains original start logic
4. Cleanup in `stop()` to remove observer

**The critical check:**
```swift
// Check flag before setting up observer - handles race condition
if CallKitManager.shared.isAudioSessionReady {
    proceedWithStart()
    return
}
// Otherwise set up observer and wait...
```

## Why This Works

1. **Prevents Race Condition:** Flag check catches when audio is already ready before observer is set up
2. **Handles Both Cases:**
   - **Audio ready first:** Flag is true → proceed immediately ✅
   - **Observer ready first:** Wait for notification → proceed when audio ready ✅
3. **Maintains Lockscreen Behavior:** Lockscreen still works perfectly (just adds explicit synchronization)
4. **Fixes Foreground:** Foreground checks flag and proceeds immediately if audio already ready
5. **Safe Timeout:** 2-second fallback ensures we don't wait forever if notification fails
6. **No Impact on Outgoing Calls:** Outgoing calls bypass the wait (they manage audio differently)
7. **Proper Cleanup:** Flag resets when call ends or audio deactivates

## Testing

### Expected Behavior After Fix

1. **Lockscreen Acceptance:**
   - Accept call on lockscreen
   - Unlock device
   - Logs should show: `✅✅✅ [CallKit] Audio session FULLY READY - setting flag and posting notification`
   - Followed by: `✅✅✅ [VoiceCallSession] CallKit audio session READY - starting WebRTC now!` (from notification)
   - Microphone works ✅
   - Track shows: `muted=false`

2. **Foreground Acceptance (FAST PATH):**
   - Accept call while app is open
   - CallKit activates audio FIRST (before VoiceCallScreen created)
   - VoiceCallSession checks flag → already true!
   - Logs should show: `✅✅✅ [VoiceCallSession] CallKit audio ALREADY READY - proceeding immediately!`
   - **NO MORE** timeout or waiting
   - Microphone works ✅
   - Track shows: `muted=false`

### Logs to Look For

**Scenario 1: Notification arrives before observer (lockscreen/slow foreground):**
```
📞 [VoiceCallSession] Incoming CallKit call - waiting for audio session...
📞 [CallKit] Audio session activated - configuring for WebRTC...
✅✅✅ [CallKit] Audio session FULLY READY - setting flag and posting notification
✅✅✅ [VoiceCallSession] CallKit audio session READY - starting WebRTC now!
```

**Scenario 2: Audio ready before observer (fast foreground) - FIXED:**
```
✅✅✅ [CallKit] Audio session FULLY READY - setting flag and posting notification
📞 [VoiceCallSession] Incoming CallKit call - waiting for audio session...
✅✅✅ [VoiceCallSession] CallKit audio ALREADY READY - proceeding immediately!
```

**WebRTC should then show:**
```
🎤 [WebRTC] Track 0: enabled=true, state=live, muted=false ✅
```

**You should NOT see:**
```
⚠️ [VoiceCallSession] Timeout waiting for CallKit audio - proceeding anyway  ❌ BAD
```

## Related Files

- `Enclosure/Utility/CallKitManager.swift` - Posts notification when audio ready
- `Enclosure/VoiceCall/VoiceCallSession.swift` - Waits for notification before starting WebRTC

## Impact

- ✅ Fixes foreground microphone muted issue
- ✅ Maintains lockscreen functionality
- ✅ No breaking changes
- ✅ Adds proper synchronization
- ✅ Safe fallback timeout
