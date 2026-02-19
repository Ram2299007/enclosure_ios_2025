# Microphone Fix: Prevent Concurrent getUserMedia() Calls

## Problem Identified
Logs revealed that `getUserMedia()` was succeeding initially but then `localStream` became `null` when the call connected:

```
✅ [WebRTC] Track 0: id=a6c72bc8-..., enabled=true, state=live
✅ [WebRTC] Local stream status: EXISTS
✅ [WebRTC] Track 0: enabled=true, state=live

[Then later when call connects...]

❌❌❌ [WebRTC] NO LOCAL STREAM - getUserMedia() not called or failed!
🎤 [WebRTC] Sender 0: kind=audio, enabled=true, state=ended
```

### Root Cause
`initializeLocalStream()` was being called **multiple times** from different places (11 call sites total), creating streams with different track IDs:
- `a6c72bc8-2fb4-442d-8a9c-a5ec0d94c9db` (initial)
- `932e4747-a81d-422e-9ec1-4e7fb1ecd84b` (duplicate call #1)
- `9c8d4f7e-1b7c-49ee-b02a-9e44d53e0a6d` (duplicate call #2)
- `cbf5e976-547e-41ed-9eb8-cbcf046cf3fc` (duplicate call #3)

Each call to `initializeLocalStream()` **stops existing tracks** and sets `localStream = null`:

```javascript
if (localStream) {
    localStream.getTracks().forEach(track => track.stop());
    localStream = null;  // <-- PROBLEM: Clears valid stream!
}
```

By the time the peer connection was established, `localStream` had been cleared to `null`, causing the audio track sender to have `state=ended`.

## Solution

### 1. Added Concurrent Call Prevention
**File**: `/Enclosure/VoiceCallAssets/scriptVoice.js`

Added `isInitializingStream` flag to prevent multiple concurrent calls:

```javascript
let isInitializingStream = false; // Prevent concurrent getUserMedia() calls
```

### 2. Enhanced `initializeLocalStream()` Function

#### A. Check for In-Progress Initialization
```javascript
if (isInitializingStream) {
    console.log('⚠️ [initializeLocalStream] Already initializing - skipping');
    if (typeof Android !== 'undefined' && Android.logToNative) {
        Android.logToNative('⚠️ [WebRTC] Already initializing stream - skipping duplicate call');
    }
    // Return existing stream if available
    if (localStream) return localStream;
    // Wait for in-progress initialization
    await new Promise(resolve => setTimeout(resolve, 100));
    return localStream;
}
```

#### B. Validate Existing Stream Before Stopping
```javascript
// Check if existing stream is still valid
if (localStream) {
    const tracks = localStream.getAudioTracks();
    const hasLiveTracks = tracks.length > 0 && tracks.every(t => t.readyState === 'live');
    
    if (hasLiveTracks) {
        console.log('✅ [initializeLocalStream] Existing stream is valid - reusing it');
        if (typeof Android !== 'undefined' && Android.logToNative) {
            Android.logToNative('✅ [WebRTC] Existing stream valid - NOT reinitializing');
            tracks.forEach((track, i) => {
                Android.logToNative(`✅ [WebRTC] Existing Track ${i}: enabled=${track.enabled}, state=${track.readyState}`);
            });
        }
        return localStream;
    } else {
        console.log('🔄 [initializeLocalStream] Existing stream invalid - stopping tracks');
        if (typeof Android !== 'undefined' && Android.logToNative) {
            Android.logToNative('🔄 [WebRTC] Existing stream has dead tracks - reinitializing');
        }
        // Stop invalid tracks
        localStream.getTracks().forEach(track => track.stop());
        localStream = null;
    }
}
```

#### C. Set Flag During Initialization
```javascript
// Set flag to prevent concurrent calls
isInitializingStream = true;

try {
    // ... getUserMedia() call ...
    
    // Clear flag on success
    isInitializingStream = false;
    return stream;
} catch (err) {
    // Clear flag on error
    isInitializingStream = false;
    
    // Try fallback...
    try {
        // ... fallback attempt ...
        
        // Clear flag on fallback success
        isInitializingStream = false;
        return stream;
    } catch (fallbackErr) {
        // Clear flag on fallback error
        isInitializingStream = false;
        throw fallbackErr;
    }
}
```

## How It Works

### Before (Broken Behavior):
1. `peer.on('open')` calls `initializeLocalStream()` → Stream A created ✅
2. Some other code calls `initializeLocalStream()` → Stream A **stopped**, Stream B created
3. Another call to `initializeLocalStream()` → Stream B **stopped**, Stream C created
4. Peer connects, tries to use `localStream` → It's been cleared to `null` ❌

### After (Fixed Behavior):
1. `peer.on('open')` calls `initializeLocalStream()` → Stream A created ✅, flag set
2. Concurrent call to `initializeLocalStream()` → **Skipped** (flag is set), returns Stream A ✅
3. Call connects → Stream A still exists and has **live tracks** ✅

### With Valid Existing Stream:
1. `initializeLocalStream()` called
2. Checks if `localStream` exists → **Yes**
3. Checks if tracks are `live` → **Yes**
4. Returns existing stream **without stopping it** ✅

## Expected Behavior

### New Logs (Success Case):
```
🎤 [WebRTC] initializeLocalStream() called
✅ [WebRTC] Existing stream valid - NOT reinitializing
✅ [WebRTC] Existing Track 0: enabled=true, state=live
📞 [WebRTC] Incoming call from peer: xxx
📞 [WebRTC] Local stream status: EXISTS
✅ [WebRTC] Track 0: enabled=true, state=live
[Call answered with valid stream]
🎤 [WebRTC] Call connected - diagnosing microphone
✅✅✅ [WebRTC] Local stream exists: YES
🎤 [WebRTC] Sender 0: kind=audio, enabled=true, state=live
```

### If Concurrent Call Attempted:
```
🎤 [WebRTC] initializeLocalStream() called
⚠️ [WebRTC] Already initializing stream - skipping duplicate call
```

### If Stream Has Dead Tracks:
```
🎤 [WebRTC] initializeLocalStream() called
🔄 [WebRTC] Existing stream has dead tracks - reinitializing
🎤 [WebRTC] Calling navigator.mediaDevices.getUserMedia()...
✅ [WebRTC] getUserMedia() returned stream successfully
```

## Files Modified
- `/Enclosure/VoiceCallAssets/scriptVoice.js`:
  - Added `isInitializingStream` flag
  - Enhanced `initializeLocalStream()` with:
    - Concurrent call prevention
    - Existing stream validation
    - Stream reuse logic
    - Flag management in all code paths

## Testing Instructions

1. **Clean build** and run on device
2. **Make call from Android**
3. **Accept from iOS foreground**
4. **Check Xcode console** for:
   - `✅ [WebRTC] Existing stream valid - NOT reinitializing` (stream reused)
   - OR `⚠️ [WebRTC] Already initializing stream - skipping duplicate call` (concurrent prevented)
   - NO `❌❌❌ [WebRTC] NO LOCAL STREAM` errors
   - Sender state: `state=live` (NOT `state=ended`)

## Expected Outcome
✅ Microphone will work because:
1. `localStream` won't be cleared during concurrent calls
2. Valid streams are reused instead of destroyed
3. Only invalid streams are reinitialized
4. Audio track will have `state=live` when peer connection sends it
