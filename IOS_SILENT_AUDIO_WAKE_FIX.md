# iOS Silent Audio Wake Fix: Bypass Audio Context Suspend Block

## Issue Identified

All THREE `audioContext.resume()` attempts **hung indefinitely**:

```
🔧 [WebRTC] Audio context suspended after getUserMedia, resuming...  ← Attempt #1 (hung)
🔧 [WebRTC] Attempting to resume audio context in peer.on(open)...  ← Attempt #2 (hung)
🔧 [WebRTC] Resuming audio context in muted track recovery...  ← Attempt #3 (hung)
⏰ [WebRTC] Audio context resume taking > 2s - may be blocked by iOS  ← Timeout!
```

**Result**: Track stayed `muted=true`, no audio sent to Android.

### Root Cause: iOS WKWebView Audio Policy

iOS **strictly controls** audio in WKWebView:
- Audio contexts created as `suspended` by default
- `audioContext.resume()` requires **user interaction** or **playing audio**
- CallKit activating audio session **doesn't count** for WebView JavaScript
- Simply calling `resume()` from JS is **blocked** by iOS security policy

## Solution: Play Silent Audio Element

iOS allows audio if an **audio element** is played. This "wakes" the audio system and allows `audioContext.resume()` to succeed.

### The Silent Audio Trick

#### 1. Created `playSilentAudioToWakeIOS()` Function
**File**: `/Enclosure/VoiceCallAssets/scriptVoice.js`

```javascript
const playSilentAudioToWakeIOS = async () => {
    if (!isIOSDevice()) return;
    
    console.log('🔊 [iOS Audio Wake] Playing silent audio to wake iOS audio system...');
    if (typeof Android !== 'undefined' && Android.logToNative) {
        Android.logToNative('🔊 [WebRTC] Playing silent audio to wake iOS audio system...');
    }
    
    try {
        // Create a silent audio element with data URI (no network request)
        const silentAudio = new Audio();
        silentAudio.src = 'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA';
        silentAudio.loop = false;
        silentAudio.volume = 0.01; // Very quiet
        
        // Play it
        await silentAudio.play();
        console.log('✅ [iOS Audio Wake] Silent audio played successfully');
        if (typeof Android !== 'undefined' && Android.logToNative) {
            Android.logToNative('✅ [WebRTC] Silent audio played - iOS audio system should be active');
        }
        
        // Remove after playing
        setTimeout(() => {
            silentAudio.pause();
            silentAudio.src = '';
        }, 100);
        
        // Now try to resume audio context
        if (audioContext && audioContext.state === 'suspended') {
            if (typeof Android !== 'undefined' && Android.logToNative) {
                Android.logToNative('🔧 [WebRTC] Attempting audio context resume AFTER silent audio...');
            }
            await audioContext.resume();
            if (typeof Android !== 'undefined' && Android.logToNative) {
                Android.logToNative('✅✅✅ [WebRTC] Audio context RESUMED after silent audio trick!');
            }
        }
    } catch (err) {
        console.error('❌ [iOS Audio Wake] Failed to play silent audio:', err);
        if (typeof Android !== 'undefined' && Android.logToNative) {
            Android.logToNative('❌ [WebRTC] Silent audio play failed: ' + err.message);
        }
    }
};
```

**How It Works:**
1. Creates a tiny silent WAV file from base64 data URI (no network)
2. Sets volume to 0.01 (nearly silent, user won't hear)
3. Plays it with `audio.play()` - this "unlocks" iOS audio
4. Immediately tries `audioContext.resume()` after
5. Cleans up audio element

#### 2. Call Silent Audio at Multiple Points

**Point A: Right After getUserMedia() (in `initializeLocalStream()`)**
```javascript
if (isIOSDevice()) {
    Android.logToNative('🔊 [WebRTC] iOS detected - playing silent audio to wake system...');
    
    playSilentAudioToWakeIOS().then(() => {
        console.log('✅ [initializeLocalStream] iOS audio wake complete');
    });
}
```

**Point B: In `peer.on('open')` After Stream Created**
```javascript
if (audioContext.state === 'suspended') {
    Android.logToNative('🔊 [WebRTC] Waking iOS audio with silent audio in peer.on(open)...');
    
    playSilentAudioToWakeIOS().then(() => {
        Android.logToNative('✅ [WebRTC] iOS audio wake completed in peer.on(open)');
    });
}
```

**Point C: When Muted Track Detected**
```javascript
if (audioContext.state === 'suspended') {
    Android.logToNative('🔊 [WebRTC] Playing silent audio to wake iOS in muted track recovery...');
    
    playSilentAudioToWakeIOS().then(() => {
        Android.logToNative('✅✅✅ [WebRTC] iOS audio wake complete in muted track recovery!');
    });
}
```

## Why This Works

### iOS Audio Context Rules:
- **Blocked**: Direct `audioContext.resume()` from JS ❌
- **Allowed**: Playing `<audio>` element ✅
- **Allowed**: `audioContext.resume()` **AFTER** playing audio ✅

### The Sequence:
```
1. iOS blocks audioContext.resume() by default
2. Play silent audio element → iOS allows it (CallKit session active)
3. Silent audio plays → Wakes iOS audio system
4. audioContext.resume() → Now allowed!
5. Audio context state: suspended → running
6. Track unmutes (muted: true → false)
7. Microphone works! ✅
```

## Expected Behavior

### Success Logs (Should See):
```
🔊 [WebRTC] iOS detected - playing silent audio to wake system...
✅ [WebRTC] Silent audio played - iOS audio system should be active
🔧 [WebRTC] Attempting audio context resume AFTER silent audio...
✅✅✅ [WebRTC] Audio context RESUMED after silent audio trick!
✅✅✅ [WebRTC] Track 0 UNMUTED - microphone is now producing audio!
```

### Track Status After Wake:
```
🎤 [WebRTC] Track 0: enabled=true, state=live, muted=false  ← UNMUTED!
```

### If First Attempt Fails (Try 2nd/3rd):
```
🔊 [WebRTC] Waking iOS audio with silent audio in peer.on(open)...
✅ [WebRTC] iOS audio wake completed in peer.on(open)
✅✅✅ [WebRTC] Audio context RESUMED after silent audio trick!
```

## Files Modified
- `/Enclosure/VoiceCallAssets/scriptVoice.js`:
  - Added `playSilentAudioToWakeIOS()` function
  - Replaced direct `audioContext.resume()` with silent audio trick
  - Applied at all 3 strategic points
  - Enhanced logging for wake attempts

## Testing Instructions

1. **Clean build** and run on device
2. **Make call from Android**
3. **Accept from iOS foreground**
4. **Watch for these NEW logs**:

### Look for Wake Attempts:
```
🔊 [WebRTC] iOS detected - playing silent audio to wake system...
```

### Look for Success:
```
✅ [WebRTC] Silent audio played - iOS audio system should be active
✅✅✅ [WebRTC] Audio context RESUMED after silent audio trick!
```

### Look for Unmute:
```
✅✅✅ [WebRTC] Track 0 UNMUTED - microphone is now producing audio!
```

### Check Track State:
```
🎤 [WebRTC] Track 0: enabled=true, state=live, muted=false  ← Should be false!
```

## Expected Outcome

✅ **Silent audio plays** → iOS audio system wakes → Audio context resumes → Track unmutes → **Microphone works!**

This is a proven iOS workaround used by many WebRTC apps. The silent audio "unlocks" the audio system without user interaction.

## Fallback If This Doesn't Work

If silent audio also fails/hangs, possible next steps:
1. **Native-to-JS signal**: Call `playSilentAudioToWakeIOS()` from native Swift when CallKit activates
2. **User interaction required**: Show "Tap to activate microphone" button
3. **New getUserMedia**: Request new stream from scratch when muted
4. **Remove audio context entirely**: Don't create AudioContext, let WebRTC handle it

The logs will tell us which approach is needed.
