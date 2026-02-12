let roomId = '';
let myUid = '';
let remoteCallerPhoto = null;
let remoteCallerName = null;
let isDisconnected = false;
let selectedAudioButton = null;
let localStream = null;
let audioOutputInitialized = false; // Global flag to track first-time setup
let audioContext = null; // Audio context for better audio processing
let audioWorkletNode = null; // Audio worklet for processing
let isAudioInitialized = false; // Track audio initialization state
let callTimerInterval = null;
let callStartTimestamp = null;

const isIOSDevice = () => /iphone|ipad|ipod/i.test(navigator.userAgent || '');

// PeerJS server configuration constants
// Use public PeerJS servers by default, fallback to custom server
const PUBLIC_PEER_SERVER = '0.peerjs.com';
const FALLBACK_PEER_SERVER = 'peer.enclosureapp.com';
const PEER_PORT = 443;
const PEER_PATH = '/';
const PEER_SECURE = true;

// WiFi detection function
function isWifiConnected() {
    console.log('[WiFi Detection] Starting WiFi connection check...');
    
    if (typeof Android !== 'undefined' && Android.isWifiConnected) {
        try {
            const wifiStatus = Android.isWifiConnected();
            console.log('[WiFi Detection] Android.isWifiConnected() returned:', wifiStatus);
            console.log('[WiFi Detection] Using Android interface for WiFi detection');
            return wifiStatus;
        } catch (err) {
            console.warn('[WiFi Detection] Failed to check WiFi status via Android:', err);
            console.log('[WiFi Detection] Fallback: assuming WiFi connected (Android interface available)');
            // Fallback: assume WiFi if Android interface is available
            return true;
        }
    }
    
    // Fallback: check using navigator.connection if available
    if (navigator.connection || navigator.mozConnection || navigator.webkitConnection) {
        const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
        const type = connection.type || connection.effectiveType;
        const effectiveType = connection.effectiveType;
        console.log('[WiFi Detection] Using navigator.connection API');
        console.log('[WiFi Detection] Connection type:', type);
        console.log('[WiFi Detection] Effective type:', effectiveType);
        // WiFi types: 'wifi', 'ethernet'
        const isWifi = type === 'wifi' || type === 'ethernet';
        console.log('[WiFi Detection] Is WiFi/Ethernet:', isWifi);
        return isWifi;
    }
    
    // Default: assume WiFi connected
    console.log('[WiFi Detection] No WiFi detection method available, defaulting to WiFi connected');
    return true;
}

// Get PeerJS server - try public first, fallback to custom
function getPeerServer() {
    console.log('[Peer Server Config] Using public PeerJS server by default');
    return PUBLIC_PEER_SERVER;
}

// Get fallback PeerJS server
function getFallbackPeerServer() {
    console.log('[Peer Server Config] Using fallback custom server');
    return FALLBACK_PEER_SERVER;
}

// Get ICE servers - always use public STUN/TURN servers
function getIceServers() {
    console.log('[ICE Servers Config] Getting ICE servers configuration...');
    // Always use public STUN/TURN servers for better connectivity
    const iceServers = [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
        { urls: 'stun:stun2.l.google.com:19302' },
        {
            urls: 'turn:openrelay.metered.ca:80',
            username: 'openrelay.project',
            credential: 'openrelay'
        }
    ];
    console.log('[ICE Servers Config] Using public STUN/TURN servers:');
    iceServers.forEach((server, index) => {
        if (server.urls) {
            console.log(`[ICE Servers Config]   ${index + 1}. ${server.urls}${server.username ? ' (with credentials)' : ''}`);
        }
    });
    return iceServers;
}

// Get current peer server
const PEER_SERVER = getPeerServer();

// Public test URLs commented out - using custom server instead
// const PUBLIC_PEER_SERVER = '0.peerjs.com'; // Public test server - commented out

// Log PeerJS server configuration
console.log('========================================');
console.log('[PeerJS Config] Initializing PeerJS configuration...');
const peerServerUrl = `${PEER_SECURE ? 'https' : 'http'}://${PEER_SERVER}:${PEER_PORT}${PEER_PATH}`;
const wifiStatus = isWifiConnected();
const iceServers = getIceServers();
console.log('========================================');
console.log('[PeerJS Config] === PEERJS INITIAL CONFIGURATION ===');
console.log('[PeerJS Config] WiFi Connected:', wifiStatus);
console.log('[PeerJS Config] Server URL:', peerServerUrl);
console.log('[PeerJS Config] Host:', PEER_SERVER);
console.log('[PeerJS Config] Port:', PEER_PORT);
console.log('[PeerJS Config] Path:', PEER_PATH);
console.log('[PeerJS Config] Secure:', PEER_SECURE);
console.log('[PeerJS Config] ICE Servers Count:', iceServers.length);
console.log('[PeerJS Config] ICE Servers Details:');
iceServers.forEach((server, index) => {
    console.log(`[PeerJS Config]   ${index + 1}. ${server.urls}${server.username ? ` (username: ${server.username})` : ''}`);
});
console.log('[PeerJS Config] ICE Candidate Pool Size:', 10);
console.log('[PeerJS Config] Debug Level: 3 (verbose)');
console.log('========================================');

// Create peer with fallback logic
let peer = new Peer({
    host: PEER_SERVER,
    port: PEER_PORT,
    path: PEER_PATH,
    secure: PEER_SECURE,
    config: {
        iceServers: iceServers,
        iceCandidatePoolSize: 10
    },
    debug: 3 // Enable detailed logging for debugging
});

// Track if we've already fallen back to avoid infinite loops
let hasFallenBack = false;

// Timeout to detect if public server isn't connecting (10 seconds)
const CONNECTION_TIMEOUT = 10000;
let connectionTimeout = setTimeout(() => {
    if (!myUid && !hasFallenBack) {
        console.log('[Peer Fallback] Public server connection timeout, switching to fallback server:', FALLBACK_PEER_SERVER);
        hasFallenBack = true;
        if (peer && !peer.destroyed) {
            peer.destroy();
        }
        // Recreate peer with fallback server
        peer = new Peer({
            host: FALLBACK_PEER_SERVER,
            port: PEER_PORT,
            path: PEER_PATH,
            secure: PEER_SECURE,
            config: {
                iceServers: iceServers,
                iceCandidatePoolSize: 10
            },
            debug: 3
        });
        // Re-attach all event handlers
        attachPeerEventHandlers();
    }
}, CONNECTION_TIMEOUT);

// Function to attach peer event handlers (called initially and after fallback)
function attachPeerEventHandlers() {
    // This will be called after peer creation and after fallback
    // Event handlers are attached below in the code
}

console.log('[PeerJS Config] Peer instance created with configuration above');

// Enhanced audio constraints for better compatibility
const getOptimalAudioConstraints = () => {
    const constraints = {
        audio: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
            sampleRate: { ideal: 48000, min: 16000, max: 48000 },
            channelCount: { ideal: 1, min: 1, max: 2 },
            latency: { ideal: 0.01, max: 0.1 },
            googEchoCancellation: true,
            googAutoGainControl: true,
            googNoiseSuppression: true,
            googHighpassFilter: true,
            googTypingNoiseDetection: true,
            googAudioMirroring: false
        },
        video: false
    };

    // Android-specific optimizations
    const userAgent = navigator.userAgent.toLowerCase();
    if (userAgent.includes('android')) {
        // Optimize for Android devices
        constraints.audio.sampleRate = { ideal: 44100, min: 16000, max: 48000 };
        constraints.audio.channelCount = { ideal: 1, min: 1, max: 1 }; // Mono for better compatibility
        constraints.audio.latency = { ideal: 0.02, max: 0.05 }; // Lower latency for Android
    }

    return constraints;
};

// Initialize audio context for better audio processing
const initializeAudioContext = async () => {
    try {
        if (!audioContext) {
            audioContext = new (window.AudioContext || window.webkitAudioContext)({
                sampleRate: 48000,
                latencyHint: 'interactive'
            });

            // Resume audio context if suspended
            if (audioContext.state === 'suspended') {
                await audioContext.resume();
            }

            console.log('Audio context initialized with state:', audioContext.state);
        }
        return audioContext;
    } catch (err) {
        console.warn('Failed to initialize audio context:', err);
        return null;
    }
};

// Enhanced local stream initialization with better error handling
const initializeLocalStream = async () => {
    try {
        if (localStream) {
            // Stop existing tracks
            localStream.getTracks().forEach(track => track.stop());
            localStream = null;
        }

        const constraints = getOptimalAudioConstraints();
        console.log('Initializing audio with constraints:', JSON.stringify(constraints));

        const stream = await navigator.mediaDevices.getUserMedia(constraints);
        localStream = stream;

        // Initialize audio context
        await initializeAudioContext();

        // Enhanced audio track configuration
        const audioTracks = localStream.getAudioTracks();
        audioTracks.forEach(track => {
            track.enabled = true;

            // Set track constraints for better quality
            if (track.getCapabilities) {
                const capabilities = track.getCapabilities();
                console.log('Audio track capabilities:', capabilities);

                // Apply optimal settings
                if (capabilities.sampleRate) {
                    track.applyConstraints({
                        sampleRate: { ideal: 48000, min: 16000, max: 48000 }
                    }).catch(err => console.warn('Failed to apply sample rate constraints:', err));
                }
            }

            console.log('Audio track initialized:', track.id, 'Enabled:', track.enabled, 'Ready state:', track.readyState);
        });

        // Monitor audio levels for debugging
        if (audioContext) {
            const source = audioContext.createMediaStreamSource(stream);
            const analyser = audioContext.createAnalyser();
            analyser.fftSize = 256;
            source.connect(analyser);

            const dataArray = new Uint8Array(analyser.frequencyBinCount);
            const checkAudioLevels = () => {
                analyser.getByteFrequencyData(dataArray);
                const average = dataArray.reduce((a, b) => a + b) / dataArray.length;
                if (average > 0) {
                    console.log('Audio levels detected:', average);
                }
            };

            setInterval(checkAudioLevels, 1000);
        }

        isAudioInitialized = true;
        applyMuteStateToStream('local_stream_ready');
        console.log('Enhanced local audio stream initialized successfully');
        return stream;

    } catch (err) {
        console.error('Failed to initialize enhanced audio stream:', err);

        if (isIOSDevice()) {
            showMicPermissionOverlay();
        }

        // Try fallback constraints - CRITICAL: Always include echo cancellation
        if (err.name === 'OverconstrainedError' || err.name === 'ConstraintNotSatisfiedError') {
            console.log('Trying fallback audio constraints with echo cancellation...');
            try {
                // CRITICAL: Always include echo cancellation in fallback to prevent echo
                const fallbackConstraints = {
                    audio: {
                        echoCancellation: true,
                        noiseSuppression: true,
                        autoGainControl: true,
                        googEchoCancellation: true,
                        googAudioMirroring: false
                    },
                    video: false
                };
                const stream = await navigator.mediaDevices.getUserMedia(fallbackConstraints);
                localStream = stream;
                
                // Verify echo cancellation is enabled in fallback
                const audioTracks = stream.getAudioTracks();
                audioTracks.forEach(track => {
                    if (track.getSettings) {
                        const settings = track.getSettings();
                        console.log('Fallback track settings:', settings);
                        if (settings.echoCancellation === false) {
                            console.warn('WARNING: Echo cancellation disabled in fallback constraints!');
                        }
                    }
                });
                
                isAudioInitialized = true;
                applyMuteStateToStream('local_stream_fallback_ready');
                console.log('Audio initialized with fallback constraints (echo cancellation enforced)');
                return stream;
            } catch (fallbackErr) {
                console.error('Fallback audio constraints also failed:', fallbackErr);
                if (isIOSDevice()) {
                    showMicPermissionOverlay();
                }
                throw fallbackErr;
            }
        }
        throw err;
    }
};

const showMicPermissionOverlay = () => {
    if (document.getElementById('ios-mic-overlay')) return;
    const overlay = document.createElement('div');
    overlay.id = 'ios-mic-overlay';
    overlay.style.position = 'fixed';
    overlay.style.inset = '0';
    overlay.style.background = 'rgba(0,0,0,0.75)';
    overlay.style.display = 'flex';
    overlay.style.flexDirection = 'column';
    overlay.style.alignItems = 'center';
    overlay.style.justifyContent = 'center';
    overlay.style.zIndex = '9999';
    overlay.style.color = '#fff';
    overlay.style.fontFamily = '-apple-system, BlinkMacSystemFont, sans-serif';
    overlay.innerHTML = `
        <div style="font-size:16px;margin-bottom:10px;">Tap to enable microphone</div>
        <button id="ios-mic-button" style="padding:12px 20px;border-radius:20px;border:none;background:#0aa; color:#fff;font-size:15px;">Enable</button>
    `;
    document.body.appendChild(overlay);
    const button = document.getElementById('ios-mic-button');
    if (button) {
        button.addEventListener('click', () => {
            initializeLocalStream()
                .then(() => {
                    overlay.remove();
                })
                .catch(() => {
                    // keep overlay if still failing
                });
        }, { once: true });
    }
};

const peers = {};
const maxParticipants = 4; // Including local user
let networkLost = false;
let isMicMuted = false;
let currentAudioOutput = 'earpiece';
let isBluetoothAvailable = false;
let previousAudioOutput = null;
let isSpeakerOn = false; // default earpiece
let userManuallySetSpeaker = false; // Track if user manually chose speaker
let callStatusObserver = null;

let participantData = {}; // Store participant names and photos

const muteMicBtn = document.getElementById('muteMic');
const audioOutputBtn = document.getElementById('audioOutputBtn');
const audioOutputMenu = document.getElementById('audioOutputMenu');
const bluetoothOption = document.getElementById('bluetoothOption');
const audioOutputIcon = document.getElementById('audioOutputIcon');
const endCallBtn = document.getElementById('endCall');
const backBtn = document.getElementById('backBtn');
const addMemberBtn = document.getElementById('addMemberBtn');
const callerName = document.getElementById('callerName');
const callTimer = document.getElementById('callTimer');
const callStatus = document.getElementById('callStatus');
const participantsContainer = document.getElementById('participantsContainer');
const singleCallerInfo = document.getElementById('singleCallerInfo');
const gridContainer = document.getElementById('gridContainer');

function getSavedMuteState() {
    try {
        if (typeof Android !== 'undefined' && Android.getMuteState) {
            return !!Android.getMuteState();
        }
    } catch (err) {
        console.warn('[MuteState] Failed to read saved mute state:', err);
    }
    return false;
}

function applyMuteStateToStream(reason, shouldSyncNative = true) {
    let nativeOk = true;
    if (localStream) {
        localStream.getAudioTracks().forEach(track => {
            track.enabled = !isMicMuted;
        });
    }
    if (shouldSyncNative && typeof Android !== 'undefined' && Android.toggleMicrophone) {
        try {
            Android.toggleMicrophone(isMicMuted);
        } catch (err) {
            nativeOk = false;
            console.warn('[MuteState] Failed to sync mute with native:', err);
        }
    }
    if (muteMicBtn) {
        muteMicBtn.classList.toggle('muted', isMicMuted);
    }
    console.log('[MuteState] Applied mute state:', isMicMuted, 'Reason:', reason);
    return nativeOk;
}

function ensureMicVisibleDuringConnecting() {
    if (!callStatus) return;
    const statusText = (callStatus.textContent || '').toLowerCase();
    if (statusText.includes('connecting')) {
        const controlsContainer = document.querySelector('.controls-container');
        const topBar = document.querySelector('.top-bar');
        if (controlsContainer) controlsContainer.classList.remove('hidden');
        if (topBar) topBar.classList.remove('hidden');
    }
}

function enforceDefaultEarpiece(reason) {
    if (userManuallySetSpeaker) {
        return;
    }
    if (currentAudioOutput !== 'earpiece') {
        console.log('[AudioOutput] Enforcing default earpiece:', reason);
        setAudioOutput('earpiece');
        setTimeout(() => {
            forceEarpieceAudio();
        }, 200);
    }
}

function refreshOutgoingAudio(stream) {
    const newTrack = stream?.getAudioTracks?.()[0] || null;
    Object.values(peers).forEach(peerEntry => {
        const callObj = peerEntry?.call || peerEntry;
        if (!callObj) return;

        if (typeof callObj.replaceStream === 'function') {
            try {
                callObj.replaceStream(stream);
                console.log('[MicRecovery] replaceStream used for peer:', callObj.peer);
                return;
            } catch (err) {
                console.warn('[MicRecovery] replaceStream failed, falling back:', err);
            }
        }

        const pc = callObj.peerConnection;
        if (!pc) return;

        if (newTrack && pc.getSenders) {
            const sender = pc.getSenders().find(s => s.track && s.track.kind === 'audio');
            if (sender && sender.replaceTrack) {
                sender.replaceTrack(newTrack).catch(err => {
                    console.warn('[MicRecovery] Failed to replace outgoing track:', err);
                });
                return;
            }
        }

        if (newTrack && pc.addTrack) {
            try {
                pc.addTrack(newTrack, stream);
                console.log('[MicRecovery] Added track to peer:', callObj.peer);
            } catch (err) {
                console.warn('[MicRecovery] Failed to add track:', err);
            }
        }
    });
}

function ensureLocalMicActive(reason) {
    const hasStream = !!localStream;
    const tracks = localStream ? localStream.getAudioTracks() : [];
    const hasLiveTrack = tracks.some(t => t.readyState === 'live');
    const hasMutedLiveTrack = tracks.some(t => t.readyState === 'live' && t.muted);

    if (!hasStream || !hasLiveTrack || (!isMicMuted && hasMutedLiveTrack)) {
        console.warn('[MicRecovery] Local stream missing or ended, reinitializing:', reason);
        initializeLocalStream()
            .then(stream => {
                localStream = stream;
                refreshOutgoingAudio(stream);
                applyMuteStateToStream('mic_recovered');
            })
            .catch(err => {
                console.error('[MicRecovery] Failed to reinitialize local stream:', err);
            });
        return;
    }

    if (!isMicMuted) {
        tracks.forEach(track => {
            if (!track.enabled) {
                console.warn('[MicRecovery] Enabling muted track:', reason);
                track.enabled = true;
            }
        });
    }
}

function startCallTimer() {
    if (!callTimer) return;
    if (callTimerInterval) return;
    callStartTimestamp = Date.now();
    callTimerInterval = setInterval(() => {
        const elapsed = Math.floor((Date.now() - callStartTimestamp) / 1000);
        const minutes = String(Math.floor(elapsed / 60)).padStart(2, '0');
        const seconds = String(elapsed % 60).padStart(2, '0');
        callTimer.textContent = `${minutes}:${seconds}`;
    }, 1000);
}

function stopCallTimer() {
    if (callTimerInterval) {
        clearInterval(callTimerInterval);
        callTimerInterval = null;
    }
    callStartTimestamp = null;
    if (callTimer) {
        callTimer.textContent = '00:00';
    }
}

function updateAudioOutputUI(output) {
    audioOutputBtn.classList.toggle('active', output !== 'earpiece');
    switch (output) {
        case 'earpiece':
            audioOutputIcon.src = 'speaker.png';
            break;
        case 'speaker':
            audioOutputIcon.src = 'speaker.png';
            break;
        case 'bluetooth':
            audioOutputIcon.src = 'bluetooth.png';
            break;
        default:
            audioOutputIcon.src = 'speaker.png';
    }
}

// Update setAudioOutput to call the new UI function
function setAudioOutput(output) {
    console.log("[AudioOutput] Requested output:", output);

    if (output === 'bluetooth' && !isBluetoothAvailable) {
        console.warn('[AudioOutput] Bluetooth not available');
        callStatus.textContent = 'Bluetooth not available';
        return;
    }

    const shouldForceEarpiece = !audioOutputInitialized && output === 'earpiece';

    if (output !== currentAudioOutput || shouldForceEarpiece) {
        console.log('[AudioOutput] Switching from', currentAudioOutput, 'to', output, '| Force:', shouldForceEarpiece);
        previousAudioOutput = currentAudioOutput;
        currentAudioOutput = output;

        // Track if user manually chose speaker
        if (output === 'speaker' && !shouldForceEarpiece) {
            userManuallySetSpeaker = true;
            console.log('[AudioOutput] User manually set speaker mode');
        } else if (output === 'earpiece') {
            userManuallySetSpeaker = false;
            console.log('[AudioOutput] User set earpiece mode');
        }

        if (typeof Android !== 'undefined' && Android.setAudioOutput) {
            try {
                Android.setAudioOutput(output);
                console.log('[AudioOutput] Android.setAudioOutput called with:', output);

                // For earpiece, add additional verification and retry
                if (output === 'earpiece') {
                    setTimeout(() => {
                        console.log('[AudioOutput] Verifying earpiece setting...');
                        try {
                            // Force earpiece again to ensure it's set
                            Android.setAudioOutput('earpiece');
                            console.log('[AudioOutput] Earpiece verification successful');
                        } catch (verifyErr) {
                            console.warn('[AudioOutput] Earpiece verification failed:', verifyErr);
                        }
                    }, 500);
                }

            } catch (err) {
                console.error('[AudioOutput] Failed to call Android.setAudioOutput:', err);

                // For earpiece, don't fallback to speaker, retry instead
                if (output === 'earpiece') {
                    console.log('[AudioOutput] Retrying earpiece setting...');
                    setTimeout(() => {
                        try {
                            Android.setAudioOutput('earpiece');
                            console.log('[AudioOutput] Earpiece retry successful');
                        } catch (retryErr) {
                            console.error('[AudioOutput] Earpiece retry failed:', retryErr);
                            // Only fallback to speaker if all retries fail
                            try {
                                Android.setAudioOutput('speaker');
                                currentAudioOutput = 'speaker';
                                console.warn('[AudioOutput] Final fallback to speaker');
                                callStatus.textContent = 'Using speaker as fallback';
                            } catch (fallbackErr) {
                                console.error('[AudioOutput] Fallback to speaker also failed:', fallbackErr);
                                callStatus.textContent = 'Audio output failed';
                            }
                        }
                    }, 1000);
                } else {
                    // For non-earpiece outputs, use normal fallback
                    try {
                        Android.setAudioOutput('speaker');
                        currentAudioOutput = 'speaker';
                        console.warn('[AudioOutput] Fallback to speaker');
                        callStatus.textContent = 'Using speaker as fallback';
                    } catch (fallbackErr) {
                        console.error('[AudioOutput] Fallback to speaker also failed:', fallbackErr);
                        callStatus.textContent = 'Audio output failed';
                    }
                }
            }
        } else {
            console.warn('[AudioOutput] Android interface is undefined');
        }

        audioOutputInitialized = true; // Mark initialized
    } else {
        console.log('[AudioOutput] Output already set to:', currentAudioOutput);
    }

    updateAudioOutputButtonUI(); // Update button UI
    audioOutputMenu.classList.remove('show');
}



function setBluetoothAvailability(isAvailable) {
    isBluetoothAvailable = isAvailable;
    bluetoothOption.style.display = isAvailable ? 'block' : 'none';
    console.log('Bluetooth availability set to:', isAvailable);
}

// Initialize peer - called from Android
// Note: The uniqueId is used as connId in Firebase, not as PeerJS ID
// PeerJS will generate its own ID when peer.on('open') fires
function init(uniqueId) {
    console.log('[init] Peer initialization requested with uniqueId:', uniqueId);
    // Peer is already created at top level, it will connect automatically
    // The uniqueId is stored for Firebase signaling, not for PeerJS
    // Just log that initialization was requested
    if (uniqueId && uniqueId.trim() !== '') {
        console.log('[init] Waiting for PeerJS connection...');
    } else {
        console.warn('[init] Invalid uniqueId provided');
    }
}

function setRoomId(id) {
    roomId = id;
    console.log('Room ID set to:', id);
}

function setCallerInfo(name, photo, uid) {
    if (!uid || uid === "self") return; // skip invalid keys

    console.log(`[setCallerInfo] Setting info for UID: ${uid}, Name: ${name}, Photo: ${photo}`);

    if (!participantData[uid] || participantData[uid].name !== name || participantData[uid].photo !== photo) {
        participantData[uid] = {
            name: name || 'Unknown',
            photo: photo || 'user.png'
        };
        console.log(`[setCallerInfo] Updated participant data for ${uid}:`, participantData[uid]);
    }

    // If this is a remote participant (not self), also set as remote caller info
    if (uid !== myUid) {
        remoteCallerPhoto = photo;
        remoteCallerName = name;
        console.log(`[setCallerInfo] Set as remote caller: ${remoteCallerName}, ${remoteCallerPhoto}`);
    }

    if (uid === myUid) {
        const callerName = document.getElementById('callerName');
        if (callerName) callerName.textContent = name || 'Name';

        const callerImage = document.getElementById('callerImage');
        if (callerImage) callerImage.src = participantData[uid].photo;
    }

    updateParticipantsUI();
}



function updateParticipantsUI() {
    const uidList = Object.keys(participantData);
    const participantCount = uidList.length;

    console.log('Updating participants UI with uidList:', uidList, 'participantCount:', participantCount);

    singleCallerInfo.style.display = participantCount <= 2 ? 'flex' : 'none';
    gridContainer.style.display = participantCount > 2 ? 'flex' : 'none';

    // Timer styles
    callTimer.style.display = 'block';
    callTimer.style.marginTop = '10px';
    callTimer.style.fontSize = '14px';
    callTimer.style.fontWeight = '500';
    callTimer.style.color = '#808080';
    callTimer.style.fontFamily = "'Inter', sans-serif";
    callTimer.style.textAlign = 'center';
    callTimer.style.position = 'relative';
    callTimer.style.zIndex = '10';

    callStatus.style.display = 'block';
    callStatus.style.marginTop = '17px';
    callStatus.style.fontSize = '12px';
    callStatus.style.fontWeight = '700';
    callStatus.style.color = '#EA6B9';
    callStatus.style.fontFamily = "'Inter', sans-serif";
    callStatus.style.textAlign = 'center';
    callStatus.style.position = 'relative';
    callStatus.style.zIndex = '10';

    // Handle 1 participant (you only)
    if (participantCount === 1) {
        console.log("Remote Caller Photo URL:", remoteCallerPhoto);
        console.log("Participant Data Photo:", participantData[myUid]?.photo);
        const localPhoto = remoteCallerPhoto || participantData[myUid]?.photo || 'user.png';
        const localName = remoteCallerName || participantData[myUid]?.name || 'Name';

        singleCallerInfo.innerHTML = `
            <img id="callerImage" src="${localPhoto}" alt="${localName}" style="border-radius: 50%; width: 100px; height: 100px;">
            <div id="callerName" class="caller-name">${localName}</div>
        `;
        singleCallerInfo.appendChild(callTimer);
        singleCallerInfo.appendChild(callStatus);
    }

    // Handle 2 participants (you + one)
    else if (participantCount === 2) {
        const remoteUid = uidList.find(uid => uid !== myUid);
        const remotePhoto = remoteCallerPhoto || participantData[remoteUid]?.photo || 'user.png';
        const remoteName = remoteCallerName || participantData[remoteUid]?.name || 'Name';

        console.log(`[updateParticipantsUI] 2 participants - Remote UID: ${remoteUid}, Photo: ${remotePhoto}, Name: ${remoteName}`);
        console.log(`[updateParticipantsUI] remoteCallerPhoto: ${remoteCallerPhoto}, remoteCallerName: ${remoteCallerName}`);

        singleCallerInfo.innerHTML = `
            <img id="callerImage" src="${remotePhoto}" alt="${remoteName}" style="border-radius: 50%; width: 100px; height: 100px;">
            <div id="callerName" class="caller-name">${remoteName}</div>
        `;
        singleCallerInfo.appendChild(callTimer);
        singleCallerInfo.appendChild(callStatus);

        // Force image load and handle errors
        const callerImage = document.getElementById('callerImage');
        if (callerImage) {
            callerImage.onload = () => {
                console.log(`[updateParticipantsUI] Image loaded successfully: ${remotePhoto}`);
            };
            callerImage.onerror = () => {
                console.error(`[updateParticipantsUI] Failed to load image: ${remotePhoto}, using default`);
                callerImage.src = 'user.png';
            };
        }
    }

    // Handle group call layout
    else if (participantCount > 2) {
        gridContainer.innerHTML = '';
        const topDiv = document.createElement('div');
        topDiv.className = 'grid-top';

        const divider = document.createElement('div');
        divider.className = 'divider';

        const bottomDiv = document.createElement('div');
        bottomDiv.className = 'grid-bottom';

        // Add local participant
        const localParticipant = document.createElement('div');
        localParticipant.className = 'participant';
        localParticipant.innerHTML = `
            <img id="localImage" src="${participantData[myUid]?.photo || 'user.png'}" alt="Name" style="border-radius: 50%; width: 100px; height: 100px;">
            <div class="caller-name">${participantData[myUid]?.name || 'Name'}</div>
        `;
        topDiv.appendChild(localParticipant);

        // Add other participants
        const remoteUids = uidList.filter(uid => uid !== myUid);
        remoteUids.forEach((uid, index) => {
            const participant = participantData[uid];
            if (participant) {
                const participantDiv = document.createElement('div');
                participantDiv.className = 'participant';
                participantDiv.innerHTML = `
                    <img id="image-${uid}" src="${participant.photo}" alt="${participant.name}" style="border-radius: 50%; width: 100px; height: 100px;">
                    <div class="caller-name">${participant.name}</div>
                `;

                // Split into top/bottom rows
                if ((participantCount === 3 && index === 0) || (participantCount === 4 && index <= 1)) {
                    topDiv.appendChild(participantDiv);
                } else {
                    bottomDiv.appendChild(participantDiv);
                }
            }
        });

        gridContainer.appendChild(topDiv);
        gridContainer.appendChild(divider);
        gridContainer.appendChild(bottomDiv);
        gridContainer.appendChild(callTimer);
        gridContainer.appendChild(callStatus);
    }
}


function handleSignalingData(data) {
    const { type, sender, receiver, sdp, candidate } = data;
    console.log('Processing signaling data:', JSON.stringify(data, null, 2));
    if (type === 'offer' && !peers[sender] && Object.keys(peers).length < maxParticipants - 1) {
        callStatus.textContent = 'Connecting...';
        console.log('Processing offer from:', sender, 'SDP:', sdp);
        if (!localStream) {
            initializeLocalStream()
                .then(stream => {
                    localStream = stream;
                    console.log('Local stream initialized for offer from:', sender);

                    // Now make the call with the initialized stream
                    const call = peer.call(sender, stream);
                    peers[sender] = { call, remoteStream: null };
                    setupCallStreamListener(call);

                    // Send answer signal
                    const conn = peer.connect(sender);
                    conn.on('open', () => {
                        conn.send({ type: 'answer', sender: myUid, receiver: sender });
                    });

                    updateParticipantsUI();
                    console.log('Call setup completed for offer from:', sender);
                })
                .catch(err => {
                    console.error('Failed to get local media stream for offer:', err);
                    callStatus.textContent = 'Failed to access microphone';
                });
        } else {
            const call = peer.call(sender, localStream);
            peers[sender] = { call, remoteStream: null };
            setupCallStreamListener(call);

            // Send answer signal
            const conn = peer.connect(sender);
            conn.on('open', () => {
                conn.send({ type: 'answer', sender: myUid, receiver: sender });
            });

            updateParticipantsUI();
            console.log('Call setup completed with existing stream for offer from:', sender);
        }
    } else if (type === 'answer' && peers[sender]) {
        console.log('Processing answer from:', sender, 'SDP:', sdp);
        // Don't set Connected here - wait for actual stream
        callStatus.textContent = 'Connecting...';
        updateParticipantsUI(); // no arguments now

    } else if (type === 'candidate' && peers[sender]) {
        console.log('Processing ICE candidate from:', sender, 'Candidate:', candidate);
        peers[sender].call.peerConnection.addIceCandidate(new RTCIceCandidate(candidate))
            .catch(err => console.error('Failed to add ICE candidate:', err));
    } else if (type === 'endCall' && sender !== myUid) {
        console.log('Received end call signal from peer:', sender);
        if (peers[sender]) {
         //   callStatus.textContent = `${participantData[sender]?.name || 'Participant'} Left`;
            callStatus.textContent = `Disconnected`;
            peers[sender].call.close();
            const audioElement = document.getElementById(`audio-${sender}`);
            if (audioElement) audioElement.remove();
            delete peers[sender];
            delete participantData[sender];
            setTimeout(() => {
                if (Object.keys(peers).length === 0) {
                    callStatus.textContent = '';
                    stopCallTimer();
                    if (typeof Android !== 'undefined') {
                        Android.endCall();
                    }
                } else {
                    // Keep status as Connecting until stream is actually received
                    // Only set Connected when audio stream is playing
                    callStatus.textContent = 'Connecting';
                    updateParticipantsUI(); // no arguments now

                }
            }, 2000);
        }
    }
}

function updatePeers(data) {
    const uidList = data.peers;
    console.log('Updating peers:', uidList);
    if (uidList.length >= maxParticipants) {
        console.log('Maximum participants reached');
        callStatus.textContent = 'Room Full';
        return;
    }
    const activeUids = uidList.filter(uid => uid !== myUid && !peers[uid]);
    activeUids.forEach(uid => {
        if (Object.keys(peers).length < maxParticipants - 1) {
            connectToPeer(uid);
        }
    });
    updateParticipantsUI(); // no arguments now

}

// Optimized startCall function - called from Android when connId is ready
function startCall(connId) {
    console.log('[startCall] Initiating call with connId:', connId);
    if (!connId || connId.trim() === '') {
        console.error('[startCall] Invalid connId provided');
        callStatus.textContent = 'Invalid connection ID';
        return;
    }
    
    // Connect immediately if local stream is ready, otherwise wait for it
    if (localStream) {
        connectToPeer(connId, 3, 2000); // Reduced retry delay from 5000ms to 2000ms
    } else {
        console.log('[startCall] Local stream not ready, initializing...');
        initializeLocalStream()
            .then(stream => {
                localStream = stream;
                console.log('[startCall] Local stream ready, connecting to peer');
                connectToPeer(connId, 3, 2000);
            })
            .catch(err => {
                console.error('[startCall] Failed to initialize local stream:', err);
                callStatus.textContent = 'Failed to access microphone';
            });
    }
}

function connectToPeer(uid, retries = 3, delay = 2000) {
    if (retries <= 0) {
        callStatus.textContent = `Failed to connect to peer: ${uid}`;
        console.log('Connection failed for peer:', uid);
        return;
    }
    console.log('Connecting to peer:', uid, 'Attempts left:', retries);
    if (Object.keys(peers).length >= maxParticipants - 1) {
        console.log('Cannot connect: maximum participants reached');
        callStatus.textContent = 'Room Full';
        return;
    }
    callStatus.textContent = 'Connecting';
    if (!localStream) {
        initializeLocalStream()
            .then(stream => {
                localStream = stream;
                console.log('Local stream initialized for peer connection:', uid);

                // Now make the call with the initialized stream
                const call = peer.call(uid, stream);
                peers[uid] = { call, remoteStream: null };
                setupCallStreamListener(call);

                // Send offer signal
                const conn = peer.connect(uid);
                conn.on('open', () => {
                    conn.send({ type: 'offer', sender: myUid, receiver: uid });
                });

                updateParticipantsUI();
                console.log('Call setup completed for peer:', uid);
            })
            .catch(err => {
                console.error('Failed to get local media stream for peer:', err);
                callStatus.textContent = `Connecting`;
                setTimeout(() => connectToPeer(uid, retries - 1, delay * 2), delay);
            });
    } else {
        const call = peer.call(uid, localStream);
        peers[uid] = { call, remoteStream: null };
        setupCallStreamListener(call);
        const conn = peer.connect(uid);
        conn.on('open', () => {
            conn.send({ type: 'offer', sender: myUid, receiver: uid });
        });
        updateParticipantsUI(); // no arguments now

    }
}

function setupCallStreamListener(call) {
    call.on('stream', remoteStream => {
        console.log('Received remote stream from peer:', call.peer);
        if (remoteStream) {
            console.log('Remote audio tracks:', remoteStream.getAudioTracks());
            remoteStream.getAudioTracks().forEach(track => {
                console.log('Remote track enabled:', track.enabled, 'Track readyState:', track.readyState);
            });
            peers[call.peer].remoteStream = remoteStream;

            // CRITICAL: Remove existing audio element to prevent echo/duplicate playback
            const existingAudio = document.getElementById(`audio-${call.peer}`);
            if (existingAudio) {
                console.log('Removing existing audio element for peer:', call.peer, 'to prevent echo');
                existingAudio.pause();
                existingAudio.srcObject = null;
                existingAudio.remove();
            }

            // Enhanced audio element creation with better error handling
            const audioElement = document.createElement('audio');
            audioElement.id = `audio-${call.peer}`;
            audioElement.srcObject = remoteStream;
            audioElement.autoplay = true;
            audioElement.playsInline = true;
            audioElement.preload = 'auto';

            // Set audio attributes for better compatibility and echo prevention
            audioElement.setAttribute('data-peer-id', call.peer);
            audioElement.style.display = 'none'; // Hide audio element

            // Track if we've already triggered vibration for this specific call
            let hasTriggeredVibration = false;

            const markConnectedIfNeeded = (reason) => {
                if (hasTriggeredVibration || callStatus?.textContent === 'Connected') {
                    return;
                }
                callStatus.textContent = 'Connected';
                startCallTimer();
                applyMuteStateToStream('call_connected');
                ensureLocalMicActive('call_connected');
                console.log(`[CallConnected] ${reason}`);

                // 🎤 DIAGNOSTIC: Check local audio track state and log to native
                console.log('🎤🎤🎤 [WebRTC Diagnostic] ========================================');
                console.log('🎤 [WebRTC] Call connected - checking microphone stream');
                
                if (typeof Android !== 'undefined' && Android.logToNative) {
                    Android.logToNative('🎤🎤🎤 [WebRTC] ========================================');
                    Android.logToNative('🎤 [WebRTC] Call connected - diagnosing microphone');
                }
                
                if (localStream) {
                    const audioTracks = localStream.getAudioTracks();
                    console.log('🎤 [WebRTC] Local stream exists:', !!localStream);
                    console.log('🎤 [WebRTC] Audio tracks count:', audioTracks.length);
                    
                    if (typeof Android !== 'undefined' && Android.logToNative) {
                        Android.logToNative(`🎤 [WebRTC] Local stream: EXISTS`);
                        Android.logToNative(`🎤 [WebRTC] Audio tracks: ${audioTracks.length}`);
                    }
                    
                    audioTracks.forEach((track, index) => {
                        const trackInfo = {
                            id: track.id,
                            kind: track.kind,
                            label: track.label,
                            enabled: track.enabled,
                            readyState: track.readyState,
                            muted: track.muted
                        };
                        console.log(`🎤 [WebRTC] Track ${index}:`, trackInfo);
                        
                        if (typeof Android !== 'undefined' && Android.logToNative) {
                            Android.logToNative(`🎤 [WebRTC] Track ${index}: enabled=${track.enabled}, state=${track.readyState}, muted=${track.muted}`);
                            if (!track.enabled) {
                                Android.logToNative(`❌ [WebRTC] Track ${index} is DISABLED!`);
                            }
                            if (track.readyState !== 'live') {
                                Android.logToNative(`❌ [WebRTC] Track ${index} state is ${track.readyState} (should be 'live')`);
                            }
                            if (track.muted) {
                                Android.logToNative(`❌ [WebRTC] Track ${index} is MUTED!`);
                            }
                        }
                    });
                } else {
                    console.error('❌ [WebRTC] NO LOCAL STREAM!');
                    if (typeof Android !== 'undefined' && Android.logToNative) {
                        Android.logToNative('❌❌❌ [WebRTC] NO LOCAL STREAM - getUserMedia() not called or failed!');
                    }
                }
                
                // Check if tracks are added to peer connection
                Object.keys(peers).forEach(peerId => {
                    const peer = peers[peerId];
                    if (peer && peer.call && peer.call.peerConnection) {
                        const senders = peer.call.peerConnection.getSenders();
                        console.log(`🎤 [WebRTC] Peer ${peerId} senders:`, senders.length);
                        
                        if (typeof Android !== 'undefined' && Android.logToNative) {
                            Android.logToNative(`🎤 [WebRTC] Peer ${peerId}: ${senders.length} senders`);
                        }
                        
                        senders.forEach((sender, index) => {
                            if (sender.track) {
                                const senderInfo = {
                                    kind: sender.track.kind,
                                    enabled: sender.track.enabled,
                                    readyState: sender.track.readyState,
                                    muted: sender.track.muted
                                };
                                console.log(`🎤 [WebRTC] Sender ${index}:`, senderInfo);
                                
                                if (typeof Android !== 'undefined' && Android.logToNative) {
                                    Android.logToNative(`🎤 [WebRTC] Sender ${index}: kind=${sender.track.kind}, enabled=${sender.track.enabled}, state=${sender.track.readyState}`);
                                }
                            } else {
                                if (typeof Android !== 'undefined' && Android.logToNative) {
                                    Android.logToNative(`⚠️ [WebRTC] Sender ${index} has NO TRACK!`);
                                }
                            }
                        });
                    }
                });
                
                if (typeof Android !== 'undefined' && Android.logToNative) {
                    Android.logToNative('🎤🎤🎤 [WebRTC] ========================================');
                }
                console.log('🎤🎤🎤 [WebRTC Diagnostic] ========================================');

                // Trigger vibration on BOTH sides when call is connected
                if (Object.keys(peers).length > 0 && typeof Android !== 'undefined') {
                    if (Android.onCallConnected) {
                        Android.onCallConnected(); // This triggers vibration
                    }
                    Android.sendBroadcast('com.enclosure.START_TIMER');

                    // Force earpiece when call connects to ensure audio goes to earpiece
                    setTimeout(() => {
                        console.log('[CallConnected] Forcing earpiece audio after call connection...');
                        userManuallySetSpeaker = false;
                        isSpeakerOn = false;
                        setAudioOutput('earpiece');
                        forceEarpieceAudio();
                    }, 1000);
                }
                hasTriggeredVibration = true;
            };

            // Enhanced error handling for audio playback
            audioElement.onloadedmetadata = () => {
                console.log('Remote audio metadata loaded for peer:', call.peer);
                audioElement.play().catch(err => {
                    console.error('Audio playback error for peer:', call.peer, err);
                    if (err && (err.name === 'NotAllowedError' || err.name === 'NotSupportedError')) {
                        // Autoplay blocked on iOS; stream is still connected.
                        markConnectedIfNeeded('Autoplay blocked, stream active');
                    }
                    // Retry playback with user interaction
                    setTimeout(() => {
                        audioElement.play().catch(retryErr => {
                            console.error('Retry playback failed for peer:', call.peer, retryErr);
                        });
                    }, 1000);
                });
            };

            audioElement.onerror = (err) => {
                console.error('Audio element error for peer:', call.peer, err);
            };

            audioElement.onended = () => {
                console.log('Audio ended for peer:', call.peer);
            };

            document.body.appendChild(audioElement);
            console.log('Enhanced remote stream attached to audio element for peer:', call.peer);
            
            // Only set Connected when stream is actually received and playing
            // Wait for audio to be ready before showing Connected
            audioElement.addEventListener('playing', () => {
                markConnectedIfNeeded('Audio is playing - call is actually connected on BOTH sides');
            }, { once: true });
            
            // Fallback: if playing event doesn't fire, set Connected after metadata loads
            audioElement.addEventListener('loadedmetadata', () => {
                setTimeout(() => {
                    markConnectedIfNeeded('Fallback - metadata loaded, marking connected');
                }, 500);
            }, { once: true });

            // iOS may block autoplay; mark connected when stream is live.
            const hasLiveAudio = remoteStream.getAudioTracks().some(track => track.readyState === 'live');
            if (remoteStream.active && hasLiveAudio) {
                setTimeout(() => {
                    markConnectedIfNeeded('Remote stream active (autoplay may be blocked)');
                }, 300);
            }
            
            updateParticipantsUI(); // no arguments now

        } else {
            console.warn('Received null or undefined stream from peer:', call.peer);
            callStatus.textContent = `Connecting`;
        }
    });
    call.on('close', () => {
        console.log('Call closed with peer:', call.peer);
        const audioElement = document.getElementById(`audio-${call.peer}`);
        if (audioElement) audioElement.remove();
        callStatus.textContent = `Disconnected`;
        delete peers[call.peer];
        delete participantData[call.peer];
        setTimeout(() => {
            if (Object.keys(peers).length === 0) {
                callStatus.textContent = '';
                stopCallTimer();
                if (typeof Android !== 'undefined') {
                    Android.endCall();
                }
            } else {
                // Keep status as Connecting until stream is actually received
                // Only set Connected when audio stream is playing
                callStatus.textContent = 'Connecting';
                updateParticipantsUI(); // no arguments now

            }
        }, 2000);
    });
    call.on('error', err => {
        console.error('Call error with peer:', call.peer, err);
        callStatus.textContent = `Connecting`;
    });
    // Enhanced ICE connection state monitoring
    call.peerConnection.oniceconnectionstatechange = () => {
        const state = call.peerConnection.iceConnectionState;
        console.log('ICE connection state for peer', call.peer, ':', state);

        if (state === 'disconnected' || state === 'failed') {
            callStatus.textContent = 'Connection lost. Reconnecting...';
            console.warn(`[ICE] Connection lost for peer ${call.peer}, state: ${state}`);

            // Wait a bit before retrying to avoid spamming reconnect
            setTimeout(() => {
                console.log(`[ICE] Attempting to reconnect to peer ${call.peer}`);
                connectToPeer(call.peer);
            }, 2000);
        }
        else if (state === 'connected' || state === 'completed') {
            // Don't set Connected here - wait for actual audio stream
            // callStatus.textContent = 'Connected';
            console.log(`[ICE] Connection established for peer ${call.peer}, waiting for stream...`);

            // Monitor connection quality
            monitorConnectionQuality(call.peerConnection, call.peer);
        }
        else if (state === 'checking') {
            callStatus.textContent = 'Connecting...';
            console.log(`[ICE] Checking connection for peer ${call.peer}`);
        }
    };

    // Monitor connection state changes
    call.peerConnection.onconnectionstatechange = () => {
        const state = call.peerConnection.connectionState;
        console.log('Connection state for peer', call.peer, ':', state);

        if (state === 'failed') {
            console.error(`[Connection] Connection failed for peer ${call.peer}`);
            callStatus.textContent = 'Connection failed. Retrying...';
            setTimeout(() => connectToPeer(call.peer), 3000);
        }
    };

    // Monitor signaling state changes
    call.peerConnection.onsignalingstatechange = () => {
        const state = call.peerConnection.signalingState;
        console.log('Signaling state for peer', call.peer, ':', state);

        if (state === 'closed') {
            console.warn(`[Signaling] Signaling closed for peer ${call.peer}`);
        }
    };

    // Remove duplicate signaling state handler since we have enhanced one above
}

muteMicBtn.addEventListener('click', () => {
    isMicMuted = !isMicMuted;
    const nativeOk = applyMuteStateToStream('user_toggle', true);
    if (nativeOk) {
        if (typeof Android !== 'undefined' && Android.saveMuteState) {
            Android.saveMuteState(isMicMuted);
        }
        console.log('Microphone mute state applied:', isMicMuted);
    } else {
        console.error('Failed to toggle microphone via native bridge');
        callStatus.textContent = 'Microphone toggle failed';
        isMicMuted = !isMicMuted; // Revert state on failure
        applyMuteStateToStream('user_toggle_revert', false);
    }
});

audioOutputBtn.addEventListener('click', () => {
   isSpeakerOn = !isSpeakerOn;
       const newOutput = isSpeakerOn ? 'speaker' : 'earpiece';

       // Explicitly set the manual choice flag
       if (newOutput === 'speaker') {
           userManuallySetSpeaker = true;
           console.log('[SpeakerButton] User clicked speaker button');
       } else {
           userManuallySetSpeaker = false;
           console.log('[SpeakerButton] User clicked earpiece button');
       }

       setAudioOutput(newOutput); // Use setAudioOutput for consistency
});

function updateAudioOutputButtonUI() {
    const btn = document.getElementById('audioOutputBtn');
    const icon = document.getElementById('audioOutputIcon');

    // Apply theme color background when not on earpiece (similar to muteMicBtn)
    btn.classList.toggle('active', currentAudioOutput !== 'earpiece');

    // Update icon based on currentAudioOutput
    switch (currentAudioOutput) {
        case 'earpiece':
            icon.src = 'speaker.png';
            break;
        case 'speaker':
            icon.src = 'speaker.png';
            break;
        case 'bluetooth':
            icon.src = 'bluetooth.png';
            break;
        default:
            icon.src = 'speaker.png';
    }
}



document.querySelectorAll('.audio-option').forEach(option => {
    option.addEventListener('click', () => {
        const output = option.getAttribute('data-output');

        // Set manual choice flag based on user selection
        if (output === 'speaker') {
            userManuallySetSpeaker = true;
            console.log('[AudioMenu] User selected speaker from menu');
        } else {
            userManuallySetSpeaker = false;
            console.log('[AudioMenu] User selected', output, 'from menu');
        }

        setAudioOutput(output); // Call your Android bridge or routing function

        // Remove 'selected' from previous
        if (selectedAudioButton) {
            selectedAudioButton.classList.remove('selected');
        }

        // Add 'selected' to current
        option.classList.add('selected');
        selectedAudioButton = option;
    });
});


endCallBtn.addEventListener('click', () => {
    console.log('End call button clicked');
    
    // Check with Android first - let Android decide if call can be ended
    // Android will show toast if call is not connected and return early
    console.log('Android object exists:', typeof Android !== 'undefined');
    console.log('Android.endCall exists:', typeof Android !== 'undefined' && typeof Android.endCall === 'function');
    
    if (typeof Android !== 'undefined') {
        console.log('Android object methods:', Object.keys(Android));
        
        // Test if interface is working
        if (Android.testInterface) {
            try {
                console.log('Testing Android interface...');
                Android.testInterface();
                console.log('Android.testInterface() completed');
            } catch (err) {
                console.error('Error calling Android.testInterface:', err);
            }
        }
        
        if (Android.endCall) {
            try {
                console.log('Calling Android.endCall() - Android will check connection status');
                Android.endCall();
                console.log('Android.endCall() call completed');
                // Note: JavaScript continues execution - Android handles the toast/blocking
            } catch (err) {
                console.error('Error calling Android.endCall:', err);
                console.error('Error stack:', err.stack);
            }
        } else {
            console.error('Android.endCall method does not exist!');
        }
    } else {
        console.error('Android object is undefined!');
    }
    
    // Continue with cleanup (Android will handle blocking if needed)
    const peerCount = Object.keys(peers).length + 1;
    if (peerCount === 2 && Object.keys(peers).length > 0) {
        const otherUid = Object.keys(peers)[0];
        const conn = peer.connect(otherUid);
        conn.on('open', () => {
            conn.send({ type: 'endCall', sender: myUid, receiver: otherUid });

        });
         endCall();
    } else {
        endCall();
    }
});

function endCall() {
    console.log('Ending call');
    // Note: Android.endCall() is already called from button handler
    stopCallTimer();
    callStatus.textContent = '';

    // Stop local stream and its tracks to prevent echo
    if (localStream) {
        localStream.getTracks().forEach(track => {
            track.stop();
            track.enabled = false;
        });
        localStream = null;
    }

    // Close all peers safely and stop remote audio streams
    Object.values(peers).forEach(p => {
        const callObj = p?.call || p; // p.call नसल्यास p direct call object असू शकतो
        
        // Stop remote stream tracks to prevent echo
        if (p?.remoteStream) {
            p.remoteStream.getTracks().forEach(track => {
                track.stop();
                track.enabled = false;
            });
        }
        
        // Remove and stop audio elements to prevent echo
        if (callObj?.peer) {
            const audioElement = document.getElementById(`audio-${callObj.peer}`);
            if (audioElement) {
                audioElement.pause();
                // Stop tracks before clearing srcObject
                if (audioElement.srcObject) {
                    audioElement.srcObject.getTracks().forEach(track => {
                        track.stop();
                        track.enabled = false;
                    });
                }
                audioElement.srcObject = null;
                audioElement.remove();
            }
        }
        
        if (callObj && typeof callObj.close === 'function') {
            callObj.close();
        }
    });

    // Destroy main peer
    if (peer && typeof peer.destroy === 'function') {
        peer.destroy();
    }

    // Reset UI
    document.body.style.background = "url('callnewmodernbg.png') no-repeat center center fixed";
    document.body.style.backgroundSize = "cover";
    document.body.style.backgroundColor = "#000";
}


backBtn.addEventListener('click', () => {
    console.log('Back button clicked');
    if (typeof Android !== 'undefined') {
        try {
            Android.callOnBackPressed();
            console.log('Called Android.callOnBackPressed');
        } catch (err) {
            console.error('Error calling Android.callOnBackPressed:', err);
            callStatus.textContent = 'Back action failed';
        }
    } else {
        console.warn('Android interface not available');
        callStatus.textContent = '';
    }
});

addMemberBtn.addEventListener('click', () => {
    console.log('Add member button clicked');
    if (Object.keys(peers).length >= maxParticipants - 1) {
        console.log('Maximum participants reached');
        callStatus.textContent = 'Room Full';
        return;
    }
    if (typeof Android !== 'undefined') {
        try {
            Android.addMemberBtn();
            console.log('Called Android.addMemberBtn');
        } catch (err) {
            console.error('Error calling Android.addMemberBtn:', err);
            callStatus.textContent = 'Add member failed';
        }
    } else {
        console.warn('Android interface not available');
        callStatus.textContent = '';
    }
});

// Remove duplicate DOMContentLoaded listener - main one is below

peer.on('open', id => {
    // Clear connection timeout since we connected successfully
    if (connectionTimeout) {
        clearTimeout(connectionTimeout);
        connectionTimeout = null;
    }
    
    myUid = id;
    callStatus.textContent = 'Connecting';
    // Re-check WiFi status for logging (may have changed)
    const currentWifiStatus = isWifiConnected();
    const currentIceServers = getIceServers();
    const currentServer = hasFallenBack ? FALLBACK_PEER_SERVER : PUBLIC_PEER_SERVER;
    const currentPeerServerUrl = `${PEER_SECURE ? 'https' : 'http'}://${currentServer}:${PEER_PORT}${PEER_PATH}`;
    console.log('========================================');
    console.log('[PeerJS Connection] === PEERJS CONNECTION ESTABLISHED ===');
    console.log('[PeerJS Connection] Successfully connected to server');
    console.log('[PeerJS Connection] Server URL:', currentPeerServerUrl);
    console.log('[PeerJS Connection] Peer ID:', id);
    console.log('[PeerJS Connection] Using server:', currentServer, hasFallenBack ? '(fallback)' : '(public)');
    console.log('[PeerJS Connection] Current WiFi Status:', currentWifiStatus);
    console.log('[PeerJS Connection] ICE Servers Count:', currentIceServers.length);
    console.log('[PeerJS Connection] Using public STUN/TURN servers for NAT traversal');
    console.log('========================================');
    if (typeof Android !== 'undefined') {
        try {
            Android.sendPeerId(id);
            Android.checkBluetoothAvailability();
            if (Android.onPeerConnected) {
                Android.onPeerConnected();
            }
            console.log('Sent peer ID and checked Bluetooth availability');
        } catch (err) {
            console.error('Error with Android interface:', err);
            callStatus.textContent = 'Connecting';
        }
    }
    initializeLocalStream()
        .then(stream => {
            localStream = stream;
            updateParticipantsUI(); // no arguments now

            // Set default audio output to earpiece for voice calls
            setTimeout(() => {
                console.log('Setting default audio output to earpiece...');
                setAudioOutput('earpiece');

                // Also force earpiece multiple times to ensure it's set
                setTimeout(() => {
                    forceEarpieceAudio();
                }, 500);

            }, 1000); // Delay to ensure Android is ready

        })
        .catch(err => {
            console.error('Failed to get local audio stream:', err);
            callStatus.textContent = 'Failed to access microphone';
        });
});

peer.on('call', incomingCall => {
    console.log('Received call from peer:', incomingCall.peer);
    callStatus.textContent = 'Connecting';

    if (!localStream) {
        initializeLocalStream()
            .then(stream => {
                localStream = stream;
                console.log('Local stream initialized for incoming call');

                // Answer the call with the local stream
                incomingCall.answer(stream);
                peers[incomingCall.peer] = { call: incomingCall, remoteStream: null };
                setupCallStreamListener(incomingCall);
                updateParticipantsUI();

                console.log('Call answered successfully');
            })
            .catch(err => {
                console.error('Failed to get local audio stream for call:', err);
                callStatus.textContent = 'Failed to access microphone';
            });
    } else {
        // Answer the call with existing local stream
        incomingCall.answer(localStream);
        peers[incomingCall.peer] = { call: incomingCall, remoteStream: null };
        setupCallStreamListener(incomingCall);
        updateParticipantsUI();

        console.log('Call answered with existing stream');
    }
});

peer.on('connection', conn => {
    conn.on('data', data => {
        console.log('Received connection data:', JSON.stringify(data, null, 2));
        handleSignalingData(data);
    });
    conn.on('error', err => {
        console.error('Connection error with peer:', conn.peer, err);
        callStatus.textContent = `Disconnected`;
    });
});

peer.on('icecandidate', event => {
    if (event.candidate) {
        console.log('Sending ICE candidate:', event.candidate);
        const conn = peer.connect(event.candidate.peer);
        conn.on('open', () => {
            conn.send({ type: 'candidate', candidate: event.candidate, sender: myUid });
        });
    }
});

peer.on('error', err => {
    console.error('========================================');
    console.error('[PeerJS Error] Connection error occurred');
    const currentServer = hasFallenBack ? FALLBACK_PEER_SERVER : PUBLIC_PEER_SERVER;
    const currentPeerServerUrl = `${PEER_SECURE ? 'https' : 'http'}://${currentServer}:${PEER_PORT}${PEER_PATH}`;
    console.error('[PeerJS Error] Server URL:', currentPeerServerUrl);
    console.error('[PeerJS Error] Error details:', err);
    console.error('[PeerJS Error] Error type:', err.type);
    console.error('========================================');
    
    // If public server fails and we haven't fallen back yet, try fallback
    if (!hasFallenBack && (err.type === 'server-error' || err.type === 'network-error' || err.type === 'socket-error' || err.type === 'unavailable-id')) {
        console.log('[Peer Fallback] Public server error detected, switching to fallback server:', FALLBACK_PEER_SERVER);
        hasFallenBack = true;
        if (connectionTimeout) {
            clearTimeout(connectionTimeout);
            connectionTimeout = null;
        }
        if (peer && !peer.destroyed) {
            peer.destroy();
        }
        // Recreate peer with fallback server
        peer = new Peer({
            host: FALLBACK_PEER_SERVER,
            port: PEER_PORT,
            path: PEER_PATH,
            secure: PEER_SECURE,
            config: {
                iceServers: iceServers,
                iceCandidatePoolSize: 10
            },
            debug: 3
        });
        // Re-attach event handlers
        attachPeerEventHandlers();
    } else {
        callStatus.textContent = `Connecting`;
    }
});

function setThemeColor(hexColor) {
    document.documentElement.style.setProperty('--theme-color', hexColor);
}

function onProximityChanged(isNear) {
    console.log('Proximity changed:', isNear ? 'Near' : 'Far');
    if (typeof Android !== 'undefined') {
        try {
            Android.checkBluetoothAvailability();
            console.log('Checked Bluetooth availability on proximity change');
        } catch (err) {
            console.error('Error checking Bluetooth availability:', err);
        }
    }
}


function setRemoteCallerInfo(photo, name) {
    remoteCallerPhoto = photo;
    remoteCallerName = name;
    console.log("[setRemoteCallerInfo] Remote caller info set:", remoteCallerPhoto, remoteCallerName);

    // Force update the UI immediately
    updateParticipantsUI();

    // Also initialize caller info for backward compatibility
    initializeCallerInfo();

    console.log("[setRemoteCallerInfo] UI updated with remote caller info");
}

// Expose setRemoteCallerInfo immediately so it's available before DOMContentLoaded
window.setRemoteCallerInfo = setRemoteCallerInfo;

function initializeCallerInfo() {
    if (!remoteCallerName && !remoteCallerPhoto) return;

    singleCallerInfo.style.display = 'flex';
    gridContainer.style.display = 'none';

    const name = remoteCallerName || 'Name';

    // आधीपासून img असल्यास reuse करा
    let img = document.getElementById('callerImage');
    if (!img) {
        img = document.createElement('img');
        img.id = 'callerImage';
        img.alt = name;
        img.style.borderRadius = '50%';
        img.style.width = '100px';
        img.style.height = '100px';
        img.style.visibility = 'hidden'; // जागा fix पण दिसणार नाही
        singleCallerInfo.appendChild(img);
    }

    let nameDiv = document.getElementById('callerName');
    if (!nameDiv) {
        nameDiv = document.createElement('div');
        nameDiv.id = 'callerName';
        nameDiv.className = 'caller-name';
        singleCallerInfo.appendChild(nameDiv);
        singleCallerInfo.appendChild(callTimer);
        singleCallerInfo.appendChild(callStatus);
    }
    nameDiv.textContent = name;

    // जर photo नाही किंवा रिकामी string असेल
    if (!remoteCallerPhoto || remoteCallerPhoto.trim() === '') {
        img.src = 'user.png';
        img.style.visibility = 'visible';
        return;
    }

    // Preload network image
    const tempImage = new Image();
    tempImage.src = remoteCallerPhoto;
    tempImage.onload = () => {
        img.src = remoteCallerPhoto;
        img.style.visibility = 'visible';
    };
    tempImage.onerror = () => {
        console.error("Failed to load caller image, showing default");
        img.src = 'user.png';
        img.style.visibility = 'visible';
    };
}





function handleNetworkLoss() {
    console.log("🔌 Network lost");

    const callStatus = document.getElementById('callStatus');
    if (callStatus) {
        callStatus.textContent = "Reconnecting";
    }

    isDisconnected = true;
    if (peer && peer.disconnected === false) {
        peer.disconnect();
    }

    sendStatusToPeers("Reconnecting...");
}


function handleNetworkResume() {
    console.log("📶 Network restored My");

    const callStatus = document.getElementById('callStatus');
    if (callStatus) {
        // Don't set Connected here - only set when actual stream is received
        callStatus.textContent = "Connecting";
    }

    if (isDisconnected) {
        isDisconnected = false;
        reconnectPeer();
    }

    sendStatusToPeers("Connected");
}

function reconnectPeer() {
    console.log('Attempting to reconnect PeerJS...');

    // Check and re-acquire localStream if invalid
    if (!localStream || localStream.getTracks().every(track => track.readyState === 'ended')) {
        console.log('Local stream is invalid or ended, re-acquiring...');
        initializeLocalStream()
            .then(stream => {
                localStream = stream;
                localStream.getAudioTracks().forEach(t => {
                    t.enabled = !isMicMuted; // Respect current mute state
                    console.log('New local audio track:', t, 'Enabled:', t.enabled);
                });
                proceedWithReconnection();
            })
            .catch(err => {
                console.error('Failed to re-acquire local stream:', err);
                callStatus.textContent = 'Failed to access microphone';
            });
    } else {
        localStream.getAudioTracks().forEach(t => {
            t.enabled = !isMicMuted; // Respect current mute state
            console.log('Existing local audio track:', t, 'Enabled:', t.enabled);
        });
        proceedWithReconnection();
    }
}

function proceedWithReconnection() {
    if (peer && !peer.destroyed) {
        peer.reconnect();
    } else {
        recreatePeer();
    }

    // Attempt to reconnect with all other participants
    setTimeout(() => {
        for (let id in participantData) {
            if (id !== myUid && !peers[id]) {
                callUser(id);
                // Resend offer to ensure signaling
                const conn = peer.connect(id);
                conn.on('open', () => {
                    conn.send({ type: 'offer', sender: myUid, receiver: id });
                });
            }
        }
    }, 1000);
}

function recreatePeer() {
    console.log('========================================');
    console.log("[Network] Recreating peer due to network change...");
    // Re-check WiFi status and get fresh configuration
    console.log('[PeerJS Reconnect] Re-checking WiFi status and configuration...');
    const currentIceServers = getIceServers();
    const currentWifiStatus = isWifiConnected();
    
    // Use fallback server if we've already determined public server doesn't work
    const reconnectServer = hasFallenBack ? FALLBACK_PEER_SERVER : PUBLIC_PEER_SERVER;
    const currentPeerServerUrl = `${PEER_SECURE ? 'https' : 'http'}://${reconnectServer}:${PEER_PORT}${PEER_PATH}`;
    
    console.log('========================================');
    console.log('[PeerJS Reconnect] === PEERJS RECONNECTION CONFIGURATION ===');
    console.log('[PeerJS Reconnect] WiFi Connected:', currentWifiStatus);
    console.log('[PeerJS Reconnect] Reconnecting to server:', reconnectServer, hasFallenBack ? '(fallback)' : '(public)');
    console.log('[PeerJS Reconnect] Server URL:', currentPeerServerUrl);
    console.log('[PeerJS Reconnect] Host:', reconnectServer);
    console.log('[PeerJS Reconnect] Port:', PEER_PORT);
    console.log('[PeerJS Reconnect] Path:', PEER_PATH);
    console.log('[PeerJS Reconnect] Secure:', PEER_SECURE);
    console.log('[PeerJS Reconnect] ICE Servers Count:', currentIceServers.length);
    console.log('[PeerJS Reconnect] ICE Servers Details:');
    currentIceServers.forEach((server, index) => {
        console.log(`[PeerJS Reconnect]   ${index + 1}. ${server.urls}${server.username ? ` (username: ${server.username})` : ''}`);
    });
    console.log('[PeerJS Reconnect] ICE Candidate Pool Size:', 10);
    console.log('[PeerJS Reconnect] Previous Peer ID:', myUid);
    console.log('========================================');

    console.log('[PeerJS Reconnect] Destroying previous peer instance...');
    try {
        peer.destroy();
        console.log('[PeerJS Reconnect] Previous peer destroyed successfully');
    } catch (e) {
        console.warn('[PeerJS Reconnect] Error destroying previous peer:', e);
    }
    
    // Clear peers object (can't reassign const, so delete all keys)
    const peerCount = Object.keys(peers).length;
    console.log(`[PeerJS Reconnect] Clearing ${peerCount} existing peer connections...`);
    Object.keys(peers).forEach(key => delete peers[key]);
    console.log('[PeerJS Reconnect] All peer connections cleared');

    console.log('[PeerJS Reconnect] Creating new peer instance with ID:', myUid);
    peer = new Peer(myUid, {
        host: reconnectServer,
        port: PEER_PORT,
        path: PEER_PATH,
        secure: PEER_SECURE,
        config: {
            iceServers: currentIceServers,
            iceCandidatePoolSize: 10
        }
    });
    console.log('[PeerJS Reconnect] New peer instance created successfully');
    console.log('========================================');

    // ⬇️ Step C - हे इथे ठेव
    window.addEventListener('offline', () => {
        networkLost = true;
        console.warn("[Network] Lost connection");
        endAllConnections();
    });

    window.addEventListener('online', () => {
        console.log("[Network] Back online");
        if (networkLost) {
            setTimeout(() => {
                recreatePeer();
                rejoinRoom();
            }, 1000);
            networkLost = false;
        }
    });

            ensureAudioAlive();

}

function rejoinRoom() {
    if (!participantData[myUid]) return;

    console.log("[Rejoin] Notifying others...");
    Android.sendRejoinSignal(myUid); // तुमच्या signalling server वरून broadcast करा

    Object.keys(participantData).forEach(pid => {
        if (pid !== myUid) {
            console.log("[Rejoin] Calling", pid);
            connectToPeer(pid); // mic stream attach करून पुन्हा call करा
        }
    });
}


function callUser(peerId) {
    if (!localStream) {
        console.warn(`[CallUser] No local stream available for peer: ${peerId}`);
        return;
    }

    console.log(`[CallUser] Calling peer: ${peerId}`);
    const call = peer.call(peerId, localStream);

    // Note: setupCallStreamListener will handle stream events, so we don't need duplicate handlers here
    // Removing duplicate stream handler to prevent echo/duplicate audio playback
    call.on('close', () => {
        console.log(`[CallUser] Call closed with peer: ${peerId}`);
        removeAudioElement(peerId);
        delete peers[peerId];
    });

    call.on('error', err => {
        console.error(`[CallUser] Call error with peer ${peerId}:`, err);
        removeAudioElement(peerId);
        delete peers[peerId];
    });

    peers[peerId] = { call, remoteStream: null };
    setupCallStreamListener(call); // This will handle the stream event
    console.log(`[CallUser] Call initiated for peer: ${peerId}`);
}

// Remove duplicate event handlers - these are already handled above
// function initPeer(uid) {
//     peer.id = uid;
//     // ... duplicate handlers removed
// }

function sendStatusToPeers(statusText) {
    for (let id in participantData) {
        if (id !== myUid) {
            const conn = peer.connect(id);
            conn.on('open', () => {
                conn.send({
                    type: "status-update",
                    from: myUid,
                    name: participantData[myUid]?.name || "User",
                    status: statusText
                });
            });
        }
    }
}



function setCallStatus(statusText) {
    console.log('XXXCallStatus called with:', statusText);
    if (callStatus) {
        callStatus.textContent = statusText;
        console.log('XXXCallStatus updated to:', statusText);
        if (statusText === 'Background') {
            console.log('App moved to background, maintaining PeerJS connection');
            // कनेक्शन सक्रिय ठेवा, कोणतेही क्लीनअप करू नका
        } else if (statusText === 'Connected') {
            console.log('App resumed, checking PeerJS connection');
            startCallTimer();
            if (isDisconnected) {
                reconnectPeer(); // कनेक्शन पुन्हा जोडा
            }
            ensureLocalMicActive('status_connected');
        }
    } else {
        console.error('XXXCallStatus element not found');
    }
}

function highlightAudioOption(output, themeColor) {
    // Remove selected state from all
    document.querySelectorAll('.audio-option').forEach(option => {
        option.classList.remove('selected');
        option.style.color = "white"; // reset unselected color
    });

    // Find matching option and add selected state
    const selectedOption = document.querySelector(`.audio-option[data-output="${output}"]`);
    if (selectedOption) {
        selectedOption.classList.add('selected');
        selectedOption.style.color = themeColor; // apply theme color
    }
}

function restoreMuteState() {
    isMicMuted = getSavedMuteState();
    applyMuteStateToStream('restore');
}


function ensureAudioAlive() {
    setInterval(() => {
        Object.keys(peers).forEach(pid => {
            const audioEl = document.getElementById(`audio-${pid}`);
            if (!audioEl || audioEl.readyState < 2) {
                console.warn(`[Recovery] No audio from ${pid}, retrying...`);
                connectToPeer(pid);
            }
        });
    }, 5000);
}

// Add missing functions that are referenced but don't exist
function addAudioStream(peerId, remoteStream) {
    console.log(`[AudioStream] Adding audio stream for peer: ${peerId}`);

    // CRITICAL: Remove existing audio element if any to prevent echo/duplicate playback
    const existingAudio = document.getElementById(`audio-${peerId}`);
    if (existingAudio) {
        console.log(`[AudioStream] Removing existing audio element for peer: ${peerId}, to prevent echo`);
        existingAudio.pause();
        existingAudio.srcObject = null;
        existingAudio.remove();
    }

    // Create new audio element
    const audioElement = document.createElement('audio');
    audioElement.id = `audio-${peerId}`;
    audioElement.srcObject = remoteStream;
    audioElement.autoplay = true;
    audioElement.playsInline = true;
    audioElement.preload = 'auto';
    audioElement.style.display = 'none';

    // Enhanced error handling
    audioElement.onloadedmetadata = () => {
        console.log(`[AudioStream] Audio metadata loaded for peer: ${peerId}`);
        audioElement.play().catch(err => {
            console.error(`[AudioStream] Playback error for peer ${peerId}:`, err);
        });
    };

    audioElement.onerror = (err) => {
        console.error(`[AudioStream] Audio element error for peer ${peerId}:`, err);
    };

    document.body.appendChild(audioElement);
    console.log(`[AudioStream] Audio stream added for peer: ${peerId}`);
}

function removeAudioElement(peerId) {
    console.log(`[AudioStream] Removing audio element for peer: ${peerId}`);
    const audioElement = document.getElementById(`audio-${peerId}`);
    if (audioElement) {
        // Properly stop audio to prevent echo
        audioElement.pause();
        if (audioElement.srcObject) {
            audioElement.srcObject.getTracks().forEach(track => {
                track.stop();
                track.enabled = false;
            });
        }
        audioElement.srcObject = null;
        audioElement.remove();
        console.log(`[AudioStream] Audio element removed for peer: ${peerId}`);
    }
    
    // Also stop remote stream tracks if available
    const peer = peers[peerId];
    if (peer?.remoteStream) {
        peer.remoteStream.getTracks().forEach(track => {
            track.stop();
            track.enabled = false;
        });
    }
}

// Alias for backward compatibility
function removeAudioStream(peerId) {
    removeAudioElement(peerId);
}

// Force earpiece function to ensure audio goes to earpiece
function forceEarpieceAudio() {
    console.log('[ForceEarpiece] Attempting to force earpiece audio...');

    if (typeof Android !== 'undefined' && Android.setAudioOutput) {
        // Try multiple times with delays to ensure earpiece is set
        const attempts = [0, 500, 1000, 2000, 3000]; // Delays in milliseconds

        attempts.forEach((delay, index) => {
            setTimeout(() => {
                try {
                    console.log(`[ForceEarpiece] Attempt ${index + 1} to set earpiece (delay: ${delay}ms)`);
                    Android.setAudioOutput('earpiece');
                    currentAudioOutput = 'earpiece';
                    console.log(`[ForceEarpiece] Attempt ${index + 1} successful`);

                    // Update UI to reflect earpiece is active
                    updateAudioOutputButtonUI();

                } catch (err) {
                    console.warn(`[ForceEarpiece] Attempt ${index + 1} failed:`, err);
                }
            }, delay);
        });

        // Also try to disable speaker explicitly
        setTimeout(() => {
            try {
                console.log('[ForceEarpiece] Explicitly disabling speaker...');
                // This might need to be implemented in Android side
                if (Android.setSpeakerphoneOn) {
                    Android.setSpeakerphoneOn(false);
                }
            } catch (err) {
                console.warn('[ForceEarpiece] Failed to disable speaker:', err);
            }
        }, 1500);

    } else {
        console.warn('[ForceEarpiece] Android interface not available');
    }
}

// Enhanced audio monitoring and recovery
function monitorAudioHealth() {
    setInterval(() => {
        // Check local stream health
        if (localStream && localStream.getAudioTracks().length > 0) {
            const audioTrack = localStream.getAudioTracks()[0];
            if (audioTrack.readyState === 'ended') {
                console.warn('[AudioHealth] Local audio track ended, reinitializing...');
                ensureLocalMicActive('audio_health_track_ended');
            }
        }

        // Check remote streams health
        Object.keys(peers).forEach(peerId => {
            const peer = peers[peerId];
            if (peer && peer.remoteStream) {
                const audioTracks = peer.remoteStream.getAudioTracks();
                if (audioTracks.length === 0 || audioTracks.every(track => track.readyState === 'ended')) {
                    console.warn(`[AudioHealth] Remote audio track ended for ${peerId}, attempting recovery...`);
                    // Try to reconnect
                    if (peer.call && peer.call.peerConnection) {
                        const state = peer.call.peerConnection.connectionState;
                        if (state === 'failed' || state === 'disconnected') {
                            console.log(`[AudioHealth] Connection state for ${peerId}: ${state}, reconnecting...`);
                            connectToPeer(peerId);
                        }
                    }
                }
            }
        });

        // Check audio context health
        if (audioContext && audioContext.state === 'suspended') {
            console.warn('[AudioHealth] Audio context suspended, resuming...');
            audioContext.resume().catch(err => {
                console.error('[AudioHealth] Failed to resume audio context:', err);
            });
        }

        // Check if audio output is still set to earpiece, if not, force it back
        // BUT only if user hasn't manually chosen speaker
        if (currentAudioOutput !== 'earpiece' && audioOutputInitialized && !userManuallySetSpeaker) {
            console.warn('[AudioHealth] Audio output changed from earpiece, forcing back to earpiece...');
            forceEarpieceAudio();
        } else if (userManuallySetSpeaker && currentAudioOutput === 'speaker') {
            console.log('[AudioHealth] User has manually set speaker, respecting their choice');
        }
    }, 3000); // Check every 3 seconds
}

// Enhanced audio recovery function
function recoverAudioStream(peerId) {
    console.log(`[AudioRecovery] Attempting to recover audio for peer: ${peerId}`);

    const peer = peers[peerId];
    if (!peer) {
        console.warn(`[AudioRecovery] Peer ${peerId} not found`);
        return;
    }

    // Remove existing audio element
    const existingAudio = document.getElementById(`audio-${peerId}`);
    if (existingAudio) {
        existingAudio.remove();
    }

    // Try to recreate the connection
    if (peer.call) {
        peer.call.close();
        delete peers[peerId];

        // Wait a bit before reconnecting
        setTimeout(() => {
            connectToPeer(peerId);
        }, 1000);
    }
}

// Connection quality monitoring function
function monitorConnectionQuality(peerConnection, peerId) {
    if (!peerConnection) return;

    try {
        // Get connection statistics
        peerConnection.getStats().then(stats => {
            stats.forEach(report => {
                if (report.type === 'inbound-rtp' && report.mediaType === 'audio') {
                    const packetsLost = report.packetsLost || 0;
                    const packetsReceived = report.packetsReceived || 0;
                    const jitter = report.jitter || 0;

                    if (packetsReceived > 0) {
                        const lossRate = (packetsLost / packetsReceived) * 100;
                        console.log(`[Quality] Peer ${peerId} - Loss: ${lossRate.toFixed(2)}%, Jitter: ${jitter.toFixed(3)}s`);

                        // Alert if quality is poor
                        if (lossRate > 5) {
                            console.warn(`[Quality] High packet loss for peer ${peerId}: ${lossRate.toFixed(2)}%`);
                            callStatus.textContent = 'Poor connection quality';
                        }
                    }
                }
            });
        }).catch(err => {
            console.warn(`[Quality] Failed to get stats for peer ${peerId}:`, err);
        });
    } catch (err) {
        console.warn(`[Quality] Error monitoring connection quality for peer ${peerId}:`, err);
    }
}

// Immediate initialization - runs before DOMContentLoaded
// Critical for lock screen calls where DOMContentLoaded might be delayed
(function immediateInit() {
    console.log('[ImmediateInit] Running immediate initialization for lock screen support');
    
    // Try to show controls immediately, even if DOM not fully loaded
    const tryShowControls = () => {
        const controlsContainer = document.querySelector('.controls-container');
        const topBar = document.querySelector('.top-bar');
        
        if (controlsContainer) {
            controlsContainer.classList.remove('hidden');
            console.log('[ImmediateInit] Controls shown immediately');
        }
        if (topBar) {
            topBar.classList.remove('hidden');
            console.log('[ImmediateInit] Top bar shown immediately');
        }
        
        // If elements not found yet, DOM is still loading
        // They'll be shown in DOMContentLoaded
        if (!controlsContainer || !topBar) {
            console.log('[ImmediateInit] Elements not ready yet, will show in DOMContentLoaded');
        }
    };
    
    // Try immediately
    tryShowControls();
    
    // Also try after a tiny delay in case DOM is almost ready
    setTimeout(tryShowControls, 50);
    setTimeout(tryShowControls, 100);
    setTimeout(tryShowControls, 200);
})();

// Initialize audio monitoring
document.addEventListener('DOMContentLoaded', () => {
    // Set initial status to Connecting
    if (callStatus) {
        callStatus.textContent = 'Connecting';
    }

    document.documentElement.style.background = "url('callnewmodernbg.png') center center / cover no-repeat";
    document.body.style.background = "url('callnewmodernbg.png') center center / cover no-repeat";
    document.body.style.backgroundColor = "#000";
    
    // Start audio health monitoring
    monitorAudioHealth();

    // Initialize existing functionality
    restoreMuteState();
    const voiceContainer = document.querySelector('.voice-container');
    const controlsContainer = document.querySelector('.controls-container');
    const topBar = document.querySelector('.top-bar');
    
    // CRITICAL: Ensure controls are visible on load, especially when accepting from lock screen
    // Remove any 'hidden' class that might have been set
    if (controlsContainer) {
        controlsContainer.classList.remove('hidden');
        console.log('[Init] Controls container made visible');
    }
    if (topBar) {
        topBar.classList.remove('hidden');
        console.log('[Init] Top bar made visible');
    }
    
    callTimer.style.display = 'block';
    callTimer.style.marginTop = '10px';
    callTimer.style.fontSize = '14px';
    callTimer.style.fontWeight = '500';
    callTimer.style.color = '#808080';

    voiceContainer.addEventListener('click', (event) => {
        if (event.target.closest('.control-btn') || event.target.closest('.top-btn') || event.target.closest('.audio-option')) return;
        controlsContainer.classList.toggle('hidden');
        topBar.classList.toggle('hidden');
        audioOutputMenu.classList.remove('show');
    });

    const onStatusChange = () => {
        ensureMicVisibleDuringConnecting();
        if (callStatus && /connecting/i.test(callStatus.textContent || '')) {
            enforceDefaultEarpiece('call_status_connecting');
        }
    };

    if (callStatus) {
        if (callStatusObserver) {
            callStatusObserver.disconnect();
        }
        callStatusObserver = new MutationObserver(onStatusChange);
        callStatusObserver.observe(callStatus, { childList: true, characterData: true, subtree: true });
        onStatusChange();
    }

    if (isIOSDevice()) {
        document.body.addEventListener('click', () => {
            if (audioContext && audioContext.state === 'suspended') {
                audioContext.resume().catch(() => {});
            }
            if (!localStream) {
                initializeLocalStream().catch(() => {});
            }
        }, { passive: true });
    }

    if (typeof Android !== 'undefined') {
        try {
            Android.onPageReady();
            console.log('Called Android.onPageReady');

            // Ensure audio output is set to earpiece on page load
            setTimeout(() => {
                console.log('Setting initial audio output to earpiece on page load...');
                setAudioOutput('earpiece');

                // Also force earpiece multiple times to ensure it's set
                setTimeout(() => {
                    forceEarpieceAudio();
                }, 500);

            }, 500);

        } catch (err) {
            console.error('Error calling Android.onPageReady:', err);
        }
    }

    // Ensure global exposure of functions for Android WebView
    window.init = init; // Expose init function for Android
    window.setRoomId = setRoomId;
    window.setRemoteCallerInfo = setRemoteCallerInfo;
    window.setThemeColor = setThemeColor;
    window.updatePeers = updatePeers;
    window.forceEarpieceAudio = forceEarpieceAudio; // Expose force earpiece function
    window.setCallerInfo = setCallerInfo;
    window.setCallStatus = setCallStatus;
    window.startCall = startCall; // Expose startCall function for Android
    window.handleNetworkResume = handleNetworkResume; // Expose network resume handler

    console.log('Voice call script initialized with global functions exposed');
});
