# iOS Microphone Unlock After Remote Playback Fix

## Problem
- CallKit activates native audio session ✅
- getUserMedia() succeeds but track is `muted=true` ❌
- Microphone never starts, no audio sent to remote peer
- Skipping AudioContext didn't fix it - not the root cause

## Root Cause
**iOS CallKit and WKWebView getUserMedia conflict:**
- CallKit takes exclusive microphone access when its audio session activates
- WKWebView's getUserMedia() can create a track, but iOS won't provide audio samples
- Result: `track.muted=true` (read-only property reflecting no audio input)
- This is an iOS system-level restriction, not a JavaScript issue

## Solution
**"Audio Unlock" Pattern:**
1. Let initial getUserMedia() succeed (even if muted)
2. Wait for **remote audio to start playing** (from Android peer)
3. When remote playback begins, **re-request getUserMedia()**
4. Now that iOS audio is "active" from playback, it allows capture
5. Replace the old muted track with the fresh un-muted track

## Implementation

### Modified: `scriptVoice.js`
In the `audioElement.addEventListener('playing')` handler:

```javascript
audioElement.addEventListener('playing', () => {
    console.log('🔊 [WebRTC] Remote audio PLAYING - iOS audio system is active');
    
    // CRITICAL iOS Fix: Now that remote audio is playing, try to fix muted local track
    if (isIOSDevice() && localStream) {
        const audioTracks = localStream.getAudioTracks();
        if (audioTracks.length > 0 && audioTracks[0].muted) {
            console.log('🔧 [WebRTC] Local track still muted, re-requesting getUserMedia after remote playback...');
            
            // Stop old muted track
            audioTracks.forEach(t => t.stop());
            
            // Request fresh microphone access now that iOS audio is active
            navigator.mediaDevices.getUserMedia({ audio: true, video: false })
                .then(newStream => {
                    localStream = newStream;
                    
                    // Replace track in all peer connections
                    Object.keys(peers).forEach(peerId => {
                        const peerData = peers[peerId];
                        if (peerData && peerData.call && peerData.call.peerConnection) {
                            const senders = peerData.call.peerConnection.getSenders();
                            senders.forEach(sender => {
                                if (sender.track && sender.track.kind === 'audio') {
                                    const newTrack = newStream.getAudioTracks()[0];
                                    sender.replaceTrack(newTrack);
                                }
                            });
                        }
                    });
                });
        }
    }
}, { once: true });
```

## How It Works

### Timeline:
1. **CallKit activates** (native iOS) → Microphone locked to CallKit
2. **WebView loads** → getUserMedia() succeeds but `muted=true`
3. **Peer connects** → WebRTC connection established
4. **Remote audio starts playing** → iOS audio system "wakes up"
5. **🔥 TRIGGER: Remote playback event fires**
6. **Fresh getUserMedia()** → Now iOS allows microphone capture!
7. **Replace muted track** → Peer connection gets working audio
8. **✅ Microphone works!** → Android can hear iOS

### Why This Works:
- iOS WKWebView requires **active audio playback** before allowing capture
- Remote audio playback satisfies iOS's "user interaction" requirement
- Once audio is playing, iOS "unlocks" the microphone for the same context
- `sender.replaceTrack()` updates the peer connection without renegotiation

## Testing

### What to Look For:
1. **Initial logs:**
   ```
   ✅ [WebRTC] Track 0: enabled=true, state=live, muted=true  ← Expected initially
   ```

2. **After remote audio plays:**
   ```
   🔊 [WebRTC] Remote audio PLAYING - iOS audio system is active
   🔧 [WebRTC] Local track still muted, re-requesting getUserMedia after remote playback...
   ✅✅✅ [WebRTC] Fresh getUserMedia() after remote plays!
   ✅ [WebRTC] New Track 0: enabled=true, state=live, muted=false  ← NOW FIXED!
   ✅✅✅ [WebRTC] Replaced muted track - mic should work now!
   ```

3. **Ask Android peer:** "Can you hear me now?"
   - Should hear iOS audio after ~1-2 seconds of connection

### If Still Doesn't Work:
- Check if remote audio actually starts playing (look for `🔊 Remote audio PLAYING`)
- Check iOS audio output (should switch to earpiece when connected)
- Try tapping screen during call (manual user interaction)

## Fallback Option
If this doesn't work, we may need to add an explicit "Tap to start microphone" button that the user taps when call connects. This guarantees a user interaction event that iOS will honor for getUserMedia().

## Files Modified
- `Enclosure/VoiceCallAssets/scriptVoice.js`

## Related Fixes
- Skip AudioContext for iOS (prevents suspended context issues)
- Prevent concurrent getUserMedia() calls (prevents stream destruction)
- Muted track detection and logging (helped diagnose this issue)

---

**Expected Behavior After Fix:**
- Call connects with `muted=true` initially (< 1 second)
- Remote audio starts playing (Android's voice heard)
- Fresh getUserMedia() fires automatically
- Track becomes `muted=false`
- Android can now hear iOS microphone!

Test and share logs! 🎤🔓
