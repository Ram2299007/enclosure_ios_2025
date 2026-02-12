# CallKit Full-Screen Dismissal Fix

## Issue
When the voice call was dismissed (user ended the call), the CallKit full-screen UI remained in the background. The app's UI would dismiss but CallKit's native full-screen interface stayed visible.

## Root Cause

### Problem: No CallKit Notification
When `VoiceCallSession.endCall()` or `stop()` was called, it only:
1. Cleaned up Firebase listeners
2. Stopped ringtone
3. Set `shouldDismiss = true` (dismissed app's VoiceCallScreen)

**But it never told CallKit to end the call!**

```swift
// BEFORE
private func endCall() {
    stopRingtone(reason: "end_call")
    cleanupFirebaseListeners()
    disableProximitySensor()
    shouldDismiss = true  // ✅ App UI dismissed
    // ❌ CallKit UI NOT dismissed - stays in background!
}
```

## Solution

### 1. Added Method to Find CallKit UUID by Room ID
**File:** `Enclosure/Utility/CallKitManager.swift`

```swift
// MARK: - Get Call UUID by Room ID
func getCallUUID(for roomId: String) -> UUID? {
    return activeCalls.first(where: { $0.value.roomId == roomId })?.key
}
```

This allows us to find the CallKit call UUID using the room ID that's already stored in `VoiceCallSession`.

### 2. Updated `stop()` Method
**File:** `Enclosure/VoiceCall/VoiceCallSession.swift`

```swift
func stop() {
    cleanupFirebaseListeners()
    stopObservingAudioInterruptions()
    stopEarpieceMonitor()
    stopRingtone(reason: "session_stop")
    disableProximitySensor()
    
    // ✅ End CallKit call if this was an incoming CallKit call
    if !payload.isSender {
        if let callKitUUID = CallKitManager.shared.getCallUUID(for: roomId) {
            NSLog("📞 [VoiceCallSession] Ending CallKit call: \(callKitUUID)")
            print("📞 [VoiceCallSession] Dismissing CallKit full-screen UI...")
            CallKitManager.shared.endCall(uuid: callKitUUID, reason: .remoteEnded)
        } else {
            NSLog("⚠️ [VoiceCallSession] No active CallKit call found for room: \(roomId)")
        }
    }
}
```

### 3. Updated `endCall()` Method
**File:** `Enclosure/VoiceCall/VoiceCallSession.swift`

```swift
private func endCall() {
    NSLog("📞 [VoiceCallSession] User ended call")
    print("📞 [VoiceCallSession] Ending call and dismissing...")
    
    stopRingtone(reason: "end_call")
    cleanupFirebaseListeners()
    disableProximitySensor()
    
    // ✅ End CallKit call if this was an incoming CallKit call
    if !payload.isSender {
        if let callKitUUID = CallKitManager.shared.getCallUUID(for: roomId) {
            NSLog("📞📞📞 [VoiceCallSession] ========================================")
            NSLog("📞 [VoiceCallSession] Ending CallKit call: \(callKitUUID)")
            NSLog("📞 [VoiceCallSession] Room: \(roomId)")
            NSLog("📞 [VoiceCallSession] Dismissing CallKit full-screen UI NOW")
            NSLog("📞📞📞 [VoiceCallSession] ========================================")
            print("📞 [VoiceCallSession] Dismissing CallKit full-screen UI...")
            CallKitManager.shared.endCall(uuid: callKitUUID, reason: .remoteEnded)
        } else {
            NSLog("⚠️ [VoiceCallSession] No active CallKit call found for room: \(roomId)")
            print("⚠️ [VoiceCallSession] CallKit call may have already ended")
        }
    }
    
    shouldDismiss = true
}
```

## How It Works

### Flow When User Ends Call

1. **User taps end call button** in VoiceCallScreen
2. **JavaScript calls** `Android.endCall()`
3. **Native receives message** → `handleMessage("endCall")` triggered
4. **`endCall()` is called:**
   - Stops ringtone
   - Cleans up Firebase
   - Disables proximity sensor
   - **Looks up CallKit UUID** using `roomId`
   - **Calls `CallKitManager.shared.endCall(uuid)`**
   - Sets `shouldDismiss = true`
5. **CallKit receives end call:**
   - `provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)`
   - CallKit full-screen UI **dismisses** ✅
6. **VoiceCallScreen dismisses** via `shouldDismiss` publisher
7. **User returns to MainActivityOld** - all UI cleared!

### Flow When Session Stops (e.g., app closing)

1. **`VoiceCallScreen.onDisappear()`** called
2. **`session.stop()`** called
3. **Same logic as endCall():**
   - Cleans up resources
   - **Finds and ends CallKit call**
   - CallKit UI dismisses ✅

## Why This Approach Works

### Using Room ID Instead of Storing UUID
- **Clean architecture** - no need to pass UUID through layers
- **Always available** - roomId is already stored in VoiceCallSession
- **Reliable lookup** - CallKitManager maintains active calls map
- **Handles edge cases** - gracefully handles if call already ended

### Only for Incoming Calls
```swift
if !payload.isSender {
    // Only end CallKit for incoming calls
    // Outgoing calls don't use CallKit (yet)
}
```

This check ensures we only try to end CallKit calls for calls that were shown via CallKit.

## Expected Behavior After Fix

### Scenario 1: User Ends Call
```
User taps "End Call" button
↓
VoiceCallSession.endCall() called
↓
CallKit UUID found via roomId
↓
CallKitManager.endCall(uuid) called
↓
CallKit full-screen UI dismisses ✅
↓
VoiceCallScreen dismisses ✅
↓
User sees MainActivityOld (clean!)
```

### Scenario 2: Remote User Ends Call
```
Firebase signals call ended
↓
JavaScript receives end signal
↓
Calls Android.endCall()
↓
Same flow as above
↓
Both app UI and CallKit UI dismiss ✅
```

### Scenario 3: App Closes During Call
```
User swipes up to close app
↓
VoiceCallScreen.onDisappear() called
↓
session.stop() called
↓
CallKit call ended
↓
CallKit UI dismissed ✅
```

## Expected Logs

When call ends, you should see:

```
📞 [VoiceCallSession] User ended call
📞 [VoiceCallSession] Ending call and dismissing...
📞📞📞 [VoiceCallSession] ========================================
📞 [VoiceCallSession] Ending CallKit call: [UUID]
📞 [VoiceCallSession] Room: [roomId]
📞 [VoiceCallSession] Dismissing CallKit full-screen UI NOW
📞📞📞 [VoiceCallSession] ========================================
📞 [VoiceCallSession] Dismissing CallKit full-screen UI...
📞 [CallKit] Ending call: [UUID]
```

## Testing Checklist

- [ ] Accept incoming CallKit call
- [ ] Wait for call to connect
- [ ] **Tap end call button**
- [ ] Verify CallKit full-screen UI dismisses (not in background)
- [ ] Verify VoiceCallScreen dismisses
- [ ] Verify you see MainActivityOld
- [ ] Test with remote user ending call
- [ ] Test with poor connection (call drops)
- [ ] Test closing app during call
- [ ] Check Xcode logs for "Dismissing CallKit full-screen UI NOW"

## Benefits

✅ **CallKit UI properly dismissed** - No lingering full-screen interface
✅ **Clean exit** - Both app UI and CallKit UI dismiss together
✅ **Proper cleanup** - CallKit resources released
✅ **Better UX** - User sees expected behavior (UI clears completely)
✅ **Handles all scenarios** - User end, remote end, app close
✅ **Detailed logging** - Easy to verify and debug
✅ **Edge case handling** - Gracefully handles if call already ended

## Implementation Details

### Why Check `!payload.isSender`?
Only incoming calls are shown via CallKit. Outgoing calls use the in-app UI (callView.swift), so they don't have a CallKit UI to dismiss.

### What is `CXCallEndedReason.remoteEnded`?
This tells CallKit why the call ended:
- `.remoteEnded` - Other person hung up (or we're ending it programmatically)
- `.unanswered` - No one answered
- `.failed` - Technical failure

We use `.remoteEnded` as it's the most general case.

### What if UUID Not Found?
If `getCallUUID(for: roomId)` returns `nil`, it means:
- Call was already ended by CallKit (user declined)
- Call never used CallKit (outgoing call)
- Call ended via different path

The warning log helps debug, but the app continues normally.
