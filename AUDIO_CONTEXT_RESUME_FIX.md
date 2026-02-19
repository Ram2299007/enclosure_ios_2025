# Audio Context Resume Fix: Multiple Resume Attempts

## Issue After Previous Fix

Muted track detection worked, but audio context resume was **hanging**:

```
🌐 [WebRTC-JS] ⚠️ Track 0 created MUTED - waiting for unmute event  ✅
🌐 [WebRTC-JS] 🔧 Audio context state: suspended  ✅
🌐 [WebRTC-JS] 🔧 Resuming audio context...  ✅
[... NO SUCCESS/FAILURE LOG ...]  ❌
[... NO UNMUTE EVENT ...]  ❌
```

### Root Cause
`audioContext.resume()` was called but the Promise **never resolved or rejected**. This means:
1. iOS is **blocking** the resume attempt
2. Resume was attempted too late (after call already connected)
3. CallKit audio session activation wasn't triggering proper audio context state

## Solution

### Try to Resume Audio Context at Multiple Strategic Points

Instead of only trying once when muted track is detected, now we attempt resume:

#### 1. **Right After getUserMedia() Success**
**Location**: `initializeLocalStream()` function

```javascript
isAudioInitialized = true;
applyMuteStateToStream('local_stream_ready');

// CRITICAL: Try to resume audio context immediately after getting stream
if (audioContext && audioContext.state === 'suspended') {
    console.log('🔧 [initializeLocalStream] Audio context suspended, resuming NOW...');
    if (typeof Android !== 'undefined' && Android.logToNative) {
        Android.logToNative('🔧 [WebRTC] Audio context suspended after getUserMedia, resuming...');
    }
    audioContext.resume().then(() => {
        Android.logToNative('✅✅✅ [WebRTC] Audio context RESUMED successfully!');
    }).catch(err => {
        Android.logToNative('❌ [WebRTC] Audio context resume failed: ' + err.message);
    });
}
```

**Why**: iOS might allow resume right after `getUserMedia()` succeeds since user just granted mic permission.

#### 2. **In peer.on('open') After Stream Creation**
**Location**: `peer.on('open')` handler

```javascript
if (typeof Android !== 'undefined' && Android.logToNative) {
    Android.logToNative('✅✅✅ [WebRTC] getUserMedia() SUCCESS in peer.on(open)');
    
    // CRITICAL: Try to resume audio context right after stream creation
    if (audioContext) {
        Android.logToNative(`🔧 [WebRTC] Audio context state in peer.on(open): ${audioContext.state}`);
        if (audioContext.state === 'suspended') {
            Android.logToNative('🔧 [WebRTC] Attempting to resume audio context in peer.on(open)...');
            audioContext.resume().then(() => {
                Android.logToNative('✅✅✅ [WebRTC] Audio context RESUMED in peer.on(open)!');
            }).catch(err => {
                Android.logToNative('❌ [WebRTC] Audio context resume failed in peer.on(open): ' + err.message);
            });
        } else {
            Android.logToNative(`✅ [WebRTC] Audio context already ${audioContext.state} - no resume needed`);
        }
    }
}
```

**Why**: When PeerJS connects, we have both user interaction (accepting call) and active audio context from CallKit.

#### 3. **When Muted Track Detected (Existing)**
**Location**: `markConnectedIfNeeded()` function (connection diagnostics)

**Enhanced** with timeout detection:

```javascript
if (audioContext.state === 'suspended') {
    Android.logToNative(`🔧 [WebRTC] Resuming audio context in muted track recovery...`);
    
    // Set a timeout to detect if resume hangs
    const resumeTimeout = setTimeout(() => {
        Android.logToNative(`⏰ [WebRTC] Audio context resume taking > 2s - may be blocked by iOS`);
    }, 2000);
    
    audioContext.resume().then(() => {
        clearTimeout(resumeTimeout);
        Android.logToNative(`✅✅✅ [WebRTC] Audio context RESUMED in muted track recovery!`);
    }).catch(err => {
        clearTimeout(resumeTimeout);
        Android.logToNative(`❌ [WebRTC] Failed to resume audio context: ${err.message}`);
    });
} else {
    Android.logToNative(`ℹ️ [WebRTC] Audio context already ${audioContext.state} - no resume needed`);
}
```

**Why**: Last resort if earlier attempts failed. Timeout helps detect if iOS is blocking.

## How It Works

### Timeline of Audio Context Resume Attempts:

```
1. Page loads → Audio context created (state: suspended)
2. CallKit activates → Native audio session active
3. getUserMedia() called → Microphone permission granted
4. ✅ ATTEMPT #1: Resume right after getUserMedia() succeeds
5. PeerJS connects → Peer open event fires
6. ✅ ATTEMPT #2: Resume in peer.on('open') after stream created
7. Android peer calls → Incoming call answered
8. Call connects → Muted track detected
9. ✅ ATTEMPT #3: Resume when muted track detected (with timeout)
```

**Strategy**: Try early and often. iOS might allow resume at any of these points.

## Expected Behavior

### Success Case (Resume Works):
```
🔧 [WebRTC] Audio context suspended after getUserMedia, resuming...
✅✅✅ [WebRTC] Audio context RESUMED successfully!
[... later ...]
✅ [WebRTC] Track 0: enabled=true, state=live, muted=false
```
→ Track never mutes OR unmutes quickly

### Partial Success (Resume Works on 2nd/3rd Attempt):
```
🔧 [WebRTC] Audio context suspended after getUserMedia, resuming...
[... no response ...]
🔧 [WebRTC] Attempting to resume audio context in peer.on(open)...
✅✅✅ [WebRTC] Audio context RESUMED in peer.on(open)!
✅✅✅ [WebRTC] Track 0 UNMUTED - microphone is now producing audio!
```
→ Track unmutes after 2nd attempt

### Still Blocked (iOS Blocking Resume):
```
🔧 [WebRTC] Resuming audio context in muted track recovery...
⏰ [WebRTC] Audio context resume taking > 2s - may be blocked by iOS
[... track stays muted ...]
```
→ Need different approach (see "Next Steps" below)

## Files Modified
- `/Enclosure/VoiceCallAssets/scriptVoice.js`:
  - Added audio context resume attempt right after `getUserMedia()` success
  - Added audio context resume attempt in `peer.on('open')` handler
  - Enhanced muted track recovery with timeout detection
  - Added state logging at each attempt

## Testing Instructions

1. **Clean build** and run on device
2. **Make call from Android**
3. **Accept from iOS foreground**
4. **Watch for new logs**:

### Look for Resume Attempts:
```
🔧 [WebRTC] Audio context suspended after getUserMedia, resuming...
```

### Look for Success:
```
✅✅✅ [WebRTC] Audio context RESUMED successfully!
```
OR
```
✅✅✅ [WebRTC] Audio context RESUMED in peer.on(open)!
```
OR
```
✅✅✅ [WebRTC] Audio context RESUMED in muted track recovery!
```

### Look for Unmute Event:
```
✅✅✅ [WebRTC] Track 0 UNMUTED - microphone is now producing audio!
```

### Check for Timeout (If Resume Hangs):
```
⏰ [WebRTC] Audio context resume taking > 2s - may be blocked by iOS
```

## Expected Outcome

### Best Case:
Audio context resumes on **1st attempt** (right after getUserMedia), track is never muted, microphone works immediately! ✅

### Good Case:
Audio context resumes on **2nd attempt** (in peer.on open), track unmutes within 1-2 seconds, microphone works! ✅

### Acceptable Case:
Audio context resumes on **3rd attempt** (muted track recovery), track unmutes after call connects, microphone works with slight delay! ✅

### Needs More Work:
All resume attempts **timeout or hang**, track stays muted. Logs will show which attempts were made and where they failed. This will guide next fix.

## Next Steps If Still Blocked

If all resume attempts fail/hang, the logs will reveal:
1. Audio context state at each attempt point
2. Whether promises resolve/reject or hang
3. Whether iOS is blocking all resume attempts

Possible next fixes if this doesn't work:
1. **Force user interaction**: Require tap/touch before allowing audio
2. **Native bridge**: Resume audio context from native iOS code through CallKit
3. **New stream**: Create fresh getUserMedia stream if track stays muted > 3s
4. **Audio element trick**: Play silent audio element to wake iOS audio system
