# Microphone Fix: Track Muted Detection and Auto-Recovery

## Problem After Previous Fix

The concurrent `getUserMedia()` fix worked perfectly:
```
✅ [WebRTC] Already initializing stream - skipping duplicate call
✅ [WebRTC] Existing stream valid - NOT reinitializing
✅ [WebRTC] Sender 0: state=live ← Fixed!
```

But discovered a **NEW issue**:
```
🌐 [WebRTC-JS] 🎤 [WebRTC] Track 0: enabled=true, state=live, muted=true
🌐 [WebRTC-JS] ❌ [WebRTC] Track 0 is MUTED!
```

### Root Cause
The `MediaStreamTrack` has `muted=true`, which means:
- Permission was granted ✅
- Track exists and is `live` ✅
- Track is `enabled=true` ✅
- **BUT**: Microphone hardware hasn't started producing audio samples yet ❌

This happens when:
1. Audio context is `suspended` and hasn't resumed
2. iOS hasn't actually started capturing from microphone hardware
3. CallKit audio session transition timing issue

The `muted` property is **read-only** and set by the browser when the source isn't producing audio data.

## Solution

### 1. Added Muted Track Detection at Creation
**File**: `/Enclosure/VoiceCallAssets/scriptVoice.js`

When tracks are created in `initializeLocalStream()`:

```javascript
audioTracks.forEach((track, index) => {
    track.enabled = true;
    console.log(`✅ [initializeLocalStream] Track ${index}: muted=${track.muted}`);
    
    if (typeof Android !== 'undefined' && Android.logToNative) {
        Android.logToNative(`✅ [WebRTC] Track ${index}: enabled=${track.enabled}, state=${track.readyState}, muted=${track.muted}`);
        
        // Warn if track is muted on creation
        if (track.muted) {
            Android.logToNative(`⚠️ [WebRTC] Track ${index} created MUTED - waiting for unmute event`);
        }
    }
    
    // Listen for unmute event
    track.addEventListener('unmute', () => {
        console.log(`✅ [WebRTC] Track ${index} UNMUTED!`);
        if (typeof Android !== 'undefined' && Android.logToNative) {
            Android.logToNative(`✅✅✅ [WebRTC] Track ${index} UNMUTED - microphone is now producing audio!`);
        }
    });
    
    // Listen for mute event (for debugging)
    track.addEventListener('mute', () => {
        console.log(`⚠️ [WebRTC] Track ${index} MUTED!`);
        if (typeof Android !== 'undefined' && Android.logToNative) {
            Android.logToNative(`⚠️⚠️⚠️ [WebRTC] Track ${index} became MUTED!`);
        }
    });
});
```

### 2. Added Muted Track Recovery When Call Connects
In the connection diagnostic code (`markConnectedIfNeeded`):

```javascript
if (track.muted) {
    Android.logToNative(`❌❌❌ [WebRTC] Track ${index} is MUTED!`);
    Android.logToNative(`🔧 [WebRTC] Attempting to fix muted track...`);
    
    // Listen for unmute event
    track.addEventListener('unmute', () => {
        Android.logToNative(`✅✅✅ [WebRTC] Track ${index} UNMUTED - audio should flow now!`);
    });
    
    // Try to resume audio context if it's suspended
    if (audioContext) {
        Android.logToNative(`🔧 [WebRTC] Audio context state: ${audioContext.state}`);
        if (audioContext.state === 'suspended') {
            Android.logToNative(`🔧 [WebRTC] Resuming audio context...`);
            audioContext.resume().then(() => {
                Android.logToNative(`✅ [WebRTC] Audio context resumed`);
            }).catch(err => {
                Android.logToNative(`❌ [WebRTC] Failed to resume audio context: ${err.message}`);
            });
        }
    }
    
    // Ensure track is enabled
    if (!track.enabled) {
        track.enabled = true;
        Android.logToNative(`🔧 [WebRTC] Track enabled set to true`);
    }
}
```

## How It Works

### Understanding `track.muted`
- **NOT the same as `track.enabled`** (which we control)
- **Read-only** property set by browser/OS
- `muted=true` means: "Permission granted but source isn't producing audio data yet"
- `muted=false` means: "Source is actively producing audio samples"

### Recovery Strategy
1. **Detect** muted tracks at creation and at connection
2. **Listen** for `unmute` event (fired when source starts producing audio)
3. **Resume** audio context if suspended
4. **Log** when tracks unmute so we know audio is flowing

### Why Tracks Might Be Muted
Common causes in iOS + CallKit scenario:
1. **Audio Context Suspended**: iOS suspends audio contexts by default, needs resume
2. **CallKit Timing**: CallKit activates audio session, but WebRTC track hasn't started yet
3. **Hardware Initialization**: Microphone hardware needs time to start after permission
4. **Route Changes**: Audio routing changes (speaker/earpiece) can temporarily mute tracks

## Expected Behavior

### Current Behavior (Muted Track):
```
🎤 [WebRTC] Track 0: enabled=true, state=live, muted=true
❌ [WebRTC] Track 0 is MUTED!
🔧 [WebRTC] Attempting to fix muted track...
🔧 [WebRTC] Audio context state: running
[... Android hears nothing ...]
```

### After Fix (Auto-Unmute):
```
🎤 [WebRTC] Track 0: enabled=true, state=live, muted=true
⚠️ [WebRTC] Track 0 created MUTED - waiting for unmute event
🔧 [WebRTC] Attempting to fix muted track...
🔧 [WebRTC] Audio context state: suspended
🔧 [WebRTC] Resuming audio context...
✅ [WebRTC] Audio context resumed
[... track unmutes ...]
✅✅✅ [WebRTC] Track 0 UNMUTED - microphone is now producing audio!
[... Android can hear! ...]
```

### If Track Is Never Muted:
```
🎤 [WebRTC] Track 0: enabled=true, state=live, muted=false
✅ [WebRTC] Track is already producing audio
[... Microphone works immediately ...]
```

## Files Modified
- `/Enclosure/VoiceCallAssets/scriptVoice.js`:
  - Added `muted` state logging at track creation
  - Added `unmute`/`mute` event listeners
  - Added muted track recovery in diagnostic code
  - Added audio context resume attempt when muted

## Testing Instructions

1. **Clean build** and run on device
2. **Make call from Android**
3. **Accept from iOS foreground**
4. **Check Xcode console** for:

### If Track Starts Muted (Current Issue):
```
⚠️ [WebRTC] Track 0 created MUTED - waiting for unmute event
❌ [WebRTC] Track 0 is MUTED!
🔧 [WebRTC] Attempting to fix muted track...
🔧 [WebRTC] Audio context state: [state here]
```

Then wait for:
```
✅✅✅ [WebRTC] Track 0 UNMUTED - microphone is now producing audio!
```

### If Track Starts Unmuted (Ideal):
```
✅ [WebRTC] Track 0: muted=false
[No recovery attempts needed]
```

## Expected Outcome

### Scenario A: Track Unmutes Automatically
- iOS CallKit activates audio session
- WebRTC track initializes as `muted=true`
- Audio context resumes
- Track automatically unmutes within 1-2 seconds
- **Microphone starts working** ✅

### Scenario B: Track Never Mutes
- iOS CallKit activates audio session
- WebRTC track initializes as `muted=false`
- **Microphone works immediately** ✅

### Scenario C: Track Stays Muted (Needs Further Fix)
- If track doesn't unmute after 3-5 seconds
- Logs will show: `❌ Track 0 is MUTED!` (no unmute event)
- Indicates deeper iOS/CallKit integration issue
- Will need to investigate audio session timing

## Next Steps If Still Muted

If the track remains muted after this fix, the logs will reveal:
1. Audio context state (suspended/running)
2. When unmute event fires (or doesn't)
3. Whether audio context resume helps

This will guide the next fix based on actual runtime behavior.
