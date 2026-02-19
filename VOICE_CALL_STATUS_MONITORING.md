# Voice Call Connection Status Monitoring

## Changes Made

### 1. Exposed Call Connection Status
Made `isCallConnected` a `@Published` property in `VoiceCallSession.swift` so the UI can monitor the connection state.

**File:** `Enclosure/VoiceCall/VoiceCallSession.swift`
```swift
final class VoiceCallSession: ObservableObject {
    @Published var shouldDismiss = false
    @Published var isCallConnected = false  // ✅ Now publicly accessible
    
    // ... rest of code
}
```

### 2. Added Connection Status Logging
Added detailed logging in `VoiceCallScreen.swift` to monitor when the call connects.

**File:** `Enclosure/VoiceCall/VoiceCallScreen.swift`
```swift
.onReceive(session.$isCallConnected) { connected in
    if connected {
        NSLog("✅✅✅ [VoiceCallScreen] ========================================")
        NSLog("✅ [VoiceCallScreen] CALL CONNECTED!")
        NSLog("✅ [VoiceCallScreen] WebRTC peer connection established")
        NSLog("✅ [VoiceCallScreen] User can now hear audio")
        NSLog("✅✅✅ [VoiceCallScreen] ========================================")
        print("✅ [VoiceCallScreen] CALL STATUS: CONNECTED")
    }
}
```

## How It Works

### Connection Detection Flow

1. **User answers CallKit call** → CallKit triggers `onAnswerCall` callback
2. **VoiceCallScreen loads** → WebView starts loading HTML
3. **WebRTC initializes** → JavaScript creates peer connection
4. **Peers connect** → JavaScript calls `Android.onCallConnected()`
5. **Status updates** → `isCallConnected = true` is set
6. **Logs appear** → Console shows "CALL CONNECTED!" message

### Expected Logs When Call Connects

```
✅✅✅ [VoiceCallScreen] ========================================
✅ [VoiceCallScreen] CALL CONNECTED!
✅ [VoiceCallScreen] WebRTC peer connection established
✅ [VoiceCallScreen] User can now hear audio
✅✅✅ [VoiceCallScreen] ========================================
✅ [VoiceCallScreen] CALL STATUS: CONNECTED
```

## Using Connection Status in Your Code

You can now monitor the connection status from any view:

```swift
struct YourView: View {
    @StateObject var session = VoiceCallSession(payload: ...)
    
    var body: some View {
        VStack {
            if session.isCallConnected {
                Text("Call Connected ✅")
                    .foregroundColor(.green)
            } else {
                Text("Connecting...")
                    .foregroundColor(.orange)
            }
        }
    }
}
```

## Bottom Button Layout Issue

### Current Investigation

The user reported: "bottom button going bottom side not like when doing call from callView.swift"

### Possible Causes

1. **Safe Area Insets**: WebView might not be calculating safe area correctly on lock screen
2. **CSS Positioning**: The `.controls-container` uses `bottom: 0` with `env(safe-area-inset-bottom)`
3. **Viewport Configuration**: Meta viewport might need adjustment for CallKit calls

### CSS Structure (Current)

```css
.controls-container {
    position: absolute;
    bottom: 0;
    left: 0;
    width: 100%;
    height: calc(80px + env(safe-area-inset-bottom));
    padding-bottom: env(safe-area-inset-bottom);
}

.controls {
    position: absolute;
    top: -20px;  /* Positioned 20px above container */
    left: 50%;
    transform: translateX(-50%);
}
```

### Next Steps

Need to understand:
1. Screenshot showing the issue (how far down are the buttons?)
2. Does it happen only when accepting from lock screen?
3. Does rotating the device fix it?
4. Compare logs between normal call vs CallKit call

## Testing

To test the connection status:

1. Make a call from Android → iOS
2. Accept on iOS via CallKit
3. Check Xcode console for "CALL CONNECTED!" logs
4. Note the timing (how long after accepting?)
5. Check if audio is working when status shows connected
