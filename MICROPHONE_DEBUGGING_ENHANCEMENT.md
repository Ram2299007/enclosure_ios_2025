# Microphone Debugging Enhancement

## Problem
Microphone not starting when accepting call from foreground notification. WebRTC diagnostic logs showed:
```
🌐 [WebRTC-JS] ❌❌❌ [WebRTC] NO LOCAL STREAM - getUserMedia() not called or failed!
🌐 [WebRTC-JS] 🎤 [WebRTC] Sender 0: kind=audio, enabled=true, state=ended
```

**Root Cause**: `localStream` was **null** at connection time, meaning `getUserMedia()` was either:
1. Not called yet
2. Failed silently
3. Returned an invalid stream

## Solution
Added comprehensive logging throughout the WebRTC initialization flow to track exactly when and why `getUserMedia()` fails or doesn't get called.

### Changes Made

#### 1. Enhanced `initializeLocalStream()` Function
**File**: `/Enclosure/VoiceCallAssets/scriptVoice.js`

Added logging at every step:
- When function is called
- When calling `getUserMedia()`
- When stream is returned
- Track details (count, state, enabled)
- Error details (name, message)
- Fallback constraint attempts

```javascript
const initializeLocalStream = async () => {
    console.log('🎤 [initializeLocalStream] Called - starting getUserMedia()');
    if (typeof Android !== 'undefined' && Android.logToNative) {
        Android.logToNative('🎤 [WebRTC] initializeLocalStream() called');
    }
    
    try {
        // ... getUserMedia() call ...
        
        console.log('✅ [initializeLocalStream] getUserMedia() returned stream');
        if (typeof Android !== 'undefined' && Android.logToNative) {
            Android.logToNative('✅ [WebRTC] getUserMedia() returned stream successfully');
        }
        
        // Log each audio track
        audioTracks.forEach((track, index) => {
            console.log(`✅ [initializeLocalStream] Track ${index}: id=${track.id}, enabled=${track.enabled}, state=${track.readyState}`);
            if (typeof Android !== 'undefined' && Android.logToNative) {
                Android.logToNative(`✅ [WebRTC] Track ${index}: id=${track.id}, enabled=${track.enabled}, state=${track.readyState}`);
            }
        });
    } catch (err) {
        console.error('❌ [initializeLocalStream] getUserMedia() failed:', err);
        if (typeof Android !== 'undefined' && Android.logToNative) {
            Android.logToNative('❌❌❌ [WebRTC] getUserMedia() FAILED: ' + err.name + ' - ' + err.message);
        }
    }
}
```

#### 2. Enhanced `peer.on('open')` Handler
Added logging when PeerJS connects and triggers `getUserMedia()`:

```javascript
peer.on('open', id => {
    // ... connection setup ...
    
    if (typeof Android !== 'undefined' && Android.logToNative) {
        Android.logToNative('📞 [WebRTC] PeerJS connected - initializing microphone');
        Android.logToNative('📞 [WebRTC] Calling getUserMedia() to get local stream...');
    }
    
    initializeLocalStream()
        .then(stream => {
            if (typeof Android !== 'undefined' && Android.logToNative) {
                Android.logToNative('✅✅✅ [WebRTC] getUserMedia() SUCCESS in peer.on(open)');
                Android.logToNative('✅ [WebRTC] Local stream created with ' + stream.getAudioTracks().length + ' audio tracks');
            }
        })
        .catch(err => {
            if (typeof Android !== 'undefined' && Android.logToNative) {
                Android.logToNative('❌❌❌ [WebRTC] getUserMedia() FAILED in peer.on(open): ' + err.message);
            }
        });
});
```

#### 3. Enhanced `peer.on('call')` Handler
Added logging when receiving incoming call to track stream status:

```javascript
peer.on('call', incomingCall => {
    if (typeof Android !== 'undefined' && Android.logToNative) {
        Android.logToNative('📞 [WebRTC] Incoming call from peer: ' + incomingCall.peer);
        Android.logToNative('📞 [WebRTC] Local stream status: ' + (localStream ? 'EXISTS' : 'NULL'));
    }

    if (!localStream) {
        if (typeof Android !== 'undefined' && Android.logToNative) {
            Android.logToNative('❌ [WebRTC] NO local stream - calling getUserMedia() now');
        }
        
        initializeLocalStream()
            .then(stream => {
                if (typeof Android !== 'undefined' && Android.logToNative) {
                    Android.logToNative('✅ [WebRTC] getUserMedia() SUCCESS - got local stream');
                    Android.logToNative('✅ [WebRTC] Audio tracks: ' + stream.getAudioTracks().length);
                    stream.getAudioTracks().forEach((track, i) => {
                        Android.logToNative(`✅ [WebRTC] Track ${i}: enabled=${track.enabled}, state=${track.readyState}`);
                    });
                }
                // Answer call...
            });
    } else {
        if (typeof Android !== 'undefined' && Android.logToNative) {
            Android.logToNative('✅ [WebRTC] Local stream already exists');
            localStream.getAudioTracks().forEach((track, i) => {
                Android.logToNative(`✅ [WebRTC] Track ${i}: enabled=${track.enabled}, state=${track.readyState}`);
            });
        }
    }
});
```

## Expected Diagnostic Output

### Success Case (Microphone Working)
```
🎤 [WebRTC] initializeLocalStream() called
🎤 [WebRTC] Calling navigator.mediaDevices.getUserMedia()...
✅ [WebRTC] getUserMedia() returned stream successfully
✅ [WebRTC] Got 1 audio tracks from getUserMedia()
✅ [WebRTC] Track 0: id=xxx, enabled=true, state=live
📞 [WebRTC] Incoming call from peer: xxx
📞 [WebRTC] Local stream status: EXISTS
✅ [WebRTC] Local stream already exists
✅ [WebRTC] Track 0: enabled=true, state=live
```

### Failure Case (Need to Fix)
```
🎤 [WebRTC] initializeLocalStream() called
🎤 [WebRTC] Calling navigator.mediaDevices.getUserMedia()...
❌❌❌ [WebRTC] getUserMedia() FAILED: [Error details]
```

OR

```
📞 [WebRTC] Incoming call from peer: xxx
📞 [WebRTC] Local stream status: NULL
❌ [WebRTC] NO local stream - calling getUserMedia() now
```

## Next Steps

1. **Test Call from Foreground**: Accept call when app is in foreground
2. **Check Xcode Console**: Look for `🌐 [WebRTC-JS]` logs
3. **Analyze Results**:
   - If `getUserMedia()` is called but fails → Check error message
   - If `getUserMedia()` succeeds but tracks are "ended" → Stream lifecycle issue
   - If `getUserMedia()` is not called at all → PeerJS event timing issue

## Files Modified
- `/Enclosure/VoiceCallAssets/scriptVoice.js` - Added comprehensive getUserMedia() logging

## Testing Instructions

1. **Clean build and run** on device
2. **Make call from Android**
3. **Accept from iOS foreground notification**
4. **Check Xcode console** for:
   - `🎤 [WebRTC] initializeLocalStream() called`
   - `✅ [WebRTC] getUserMedia() SUCCESS` or `❌ [WebRTC] getUserMedia() FAILED`
   - `📞 [WebRTC] Local stream status: EXISTS` or `NULL`
   - Track state: `state=live` or `state=ended`

## Expected Outcome
This enhanced logging will reveal:
1. When `getUserMedia()` is called
2. If it succeeds or fails
3. The state of audio tracks when call connects
4. Whether the stream exists when answering the call

This will allow us to pinpoint the exact root cause and implement the correct fix.
