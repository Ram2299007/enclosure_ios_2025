let roomId = '';
let myPeerId = '';
let localStream = null;
let currentFacingMode = 'user';

// PeerJS server configuration constants
// Use public PeerJS server by default, fallback to custom server
const PUBLIC_PEER_SERVER = '0.peerjs.com';
const FALLBACK_PEER_SERVER = 'peer.enclosureapp.com';
const PEER_PORT = 443;
const PEER_PATH = '/';
const PEER_SECURE = true;

// Get PeerJS server - use public first, fallback to custom
function getPeerServer() {
    console.log('[Peer Server Config] Using public PeerJS server by default');
    return PUBLIC_PEER_SERVER;
}

const PEER_SERVER = getPeerServer();

// WiFi detection function
function isWifiConnected() {
    console.log('========================================');
    console.log('[WiFi Detection] Starting WiFi connection check...');
    
    // First, try Android interface (most reliable)
    if (typeof Android !== 'undefined' && Android.isWifiConnected) {
        try {
            const wifiStatus = Android.isWifiConnected();
            console.log('[WiFi Detection] ✅ Android.isWifiConnected() returned:', wifiStatus);
            console.log('[WiFi Detection] Using Android interface for WiFi detection');
            console.log('========================================');
            console.log('✅✅✅ [WiFi Detection] FINAL RESULT: WiFi', wifiStatus ? 'CONNECTED ✅✅✅' : 'NOT CONNECTED ❌❌❌');
            console.log('========================================');
            return wifiStatus;
        } catch (err) {
            console.warn('[WiFi Detection] ❌ Failed to check WiFi status via Android:', err);
            console.log('[WiFi Detection] Falling back to navigator.connection API...');
        }
    } else {
        console.log('[WiFi Detection] Android.isWifiConnected() not available, using navigator.connection API...');
    }
    
    // Fallback: check using navigator.connection if available
    if (navigator.connection || navigator.mozConnection || navigator.webkitConnection) {
        const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
        const type = connection.type;
        const effectiveType = connection.effectiveType;
        const downlink = connection.downlink;
        const saveData = connection.saveData;
        
        console.log('[WiFi Detection] Using navigator.connection API');
        console.log('[WiFi Detection] Connection type:', type);
        console.log('[WiFi Detection] Effective type:', effectiveType);
        console.log('[WiFi Detection] Downlink:', downlink, 'Mbps');
        console.log('[WiFi Detection] Save data mode:', saveData);
        
        // Check for WiFi types
        const isWifi = type === 'wifi' || type === 'ethernet';
        
        // Additional check: if type is not available, check effectiveType
        // High downlink speeds (>10 Mbps) often indicate WiFi
        const likelyWifi = !type && effectiveType && (effectiveType === '4g' && downlink > 10);
        
        const finalResult = isWifi || likelyWifi;
        console.log('[WiFi Detection] Is WiFi/Ethernet (type check):', isWifi);
        console.log('[WiFi Detection] Likely WiFi (speed check):', likelyWifi);
        console.log('========================================');
        console.log('✅✅✅ [WiFi Detection] FINAL RESULT: WiFi', finalResult ? 'CONNECTED ✅✅✅' : 'NOT CONNECTED ❌❌❌');
        console.log('========================================');
        return finalResult;
    }
    
    // Default: assume WiFi connected (conservative approach)
    console.log('[WiFi Detection] ⚠️ No WiFi detection method available');
    console.log('[WiFi Detection] Defaulting to WiFi CONNECTED (conservative)');
    console.log('========================================');
    console.log('✅✅✅ [WiFi Detection] FINAL RESULT: WiFi CONNECTED ✅✅✅ (default)');
    console.log('========================================');
    return true;
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

// Log PeerJS server configuration
const peerServerUrl = `${PEER_SECURE ? 'https' : 'http'}://${PEER_SERVER}:${PEER_PORT}${PEER_PATH}`;
console.log('========================================');
console.log('[PeerJS Config] Initializing PeerJS configuration...');
const wifiStatus = isWifiConnected();
const iceServers = getIceServers();
console.log('========================================');
console.log('[PeerJS Config] === PEERJS INITIAL CONFIGURATION ===');
console.log('========================================');
console.log('📶📶📶 [PeerJS Config] WiFi Status:', wifiStatus ? '✅ CONNECTED ✅' : '❌ NOT CONNECTED ❌');
console.log('========================================');
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
console.log('[PeerJS Config] ICE Candidate Pool Size: 10');
console.log('[PeerJS Config] Debug Level: 3 (verbose)');
console.log('========================================');

// Create peer with fallback logic - public server first, fallback to custom
let peer = new Peer({
    host: PEER_SERVER,
    port: PEER_PORT,
    path: PEER_PATH,
    secure: PEER_SECURE,
    config: {
        iceServers: iceServers,
        iceCandidatePoolSize: 10
    },
    debug: 3 // Enable detailed logging for debugging perfect
});

// Track if we've already fallen back to avoid infinite loops
let hasFallenBack = false;

// Timeout to detect if public server isn't connecting (10 seconds)
const CONNECTION_TIMEOUT = 10000;
let connectionTimeout = setTimeout(() => {
    if (!myPeerId && !hasFallenBack) {
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
    // Event handlers are attached below in the code
}

console.log('[PeerJS Config] Peer instance created with configuration above');
const peers = {};
const remoteVideos = document.getElementById('remoteVideos');
const secondaryVideo = document.getElementById('secondaryVideo');
const localVideo = document.getElementById('localVideo');
const statusBar = document.getElementById('statusBar');
const muteMicBtn = document.getElementById('muteMic');
const callerName = document.getElementById('callerName');
const toggleCameraBtn = document.getElementById('toggleCamera');
const switchCameraBtn = document.getElementById('switchCamera');
const addMemberBtn = document.getElementById('addMemberBtn');
const endCallBtn = document.getElementById('endCall');
const pipButton = document.getElementById('pipButton');
let isMicMuted = false; // Default: start unmuted; user taps to mute
let isCameraOn = true;
const lastPosters = new WeakMap();
let lastLocalBlur = null;

// Ensure global exposure of functions for Android WebView and iOS native
window.setRoomId = setRoomId;
window.setRemoteCallerInfo = setRemoteCallerInfo;
window.setThemeColor = setThemeColor;
window.updatePeers = updatePeers;
window.updateVideoLayout = updateVideoLayout;
window.updateVideoMirroring = updateVideoMirroring;
window.applyConnectedLayoutFromPeers = applyConnectedLayoutFromPeers;
window.reconnectPeer = reconnectPeer;
window.handleNetworkResume = handleNetworkResume;
window.applyInitialMuteState = applyInitialMuteState;

// Initialize local stream as early as possible for faster camera startup
// Enhanced WebView camera constraints for better compatibility
const getOptimalCameraConstraints = () => {
    const constraints = {
        video: {
            width: { ideal: 640, min: 320, max: 1280 },
            height: { ideal: 360, min: 240, max: 720 },
            facingMode: 'user',
            frameRate: { ideal: 30, min: 15, max: 60 }
        },
        audio: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
            sampleRate: { ideal: 48000, min: 16000, max: 48000 },
            channelCount: { ideal: 1, min: 1, max: 2 }
        }
    };

    // Device-specific optimizations
    const userAgent = navigator.userAgent.toLowerCase();
    if (userAgent.includes('android')) {
        // Android-specific optimizations
        constraints.video.width = { ideal: 480, min: 320, max: 640 };
        constraints.video.height = { ideal: 360, min: 240, max: 480 };
        constraints.video.frameRate = { ideal: 24, min: 15, max: 30 };
    }

    return constraints;
};

// Initialize local stream with enhanced error handling
const initializeLocalStream = async () => {
    try {
        const constraints = getOptimalCameraConstraints();
        console.log('Initializing WebView camera with constraints:', JSON.stringify(constraints));

        const stream = await navigator.mediaDevices.getUserMedia(constraints);
        localStream = stream;

        // Apply saved mute state to audio tracks (e.g. restored from previous session)
        if (isMicMuted && stream.getAudioTracks().length) {
            stream.getAudioTracks().forEach(t => t.enabled = false);
        }

        // Check if a remote stream is already on primary (call already connected).
        // If so, put local stream on secondary instead of overwriting primary.
        var hasRemoteOnPrimary = localVideo.srcObject && localVideo.srcObject !== stream && localVideo.srcObject !== localStream;
        if (hasRemoteOnPrimary) {
            console.log('Remote stream already on primary - putting local on secondary');
            secondaryVideo.srcObject = stream;
            secondaryVideo.muted = true;
            secondaryVideo.autoplay = true;
            secondaryVideo.playsInline = true;
            secondaryVideo.classList.add('secondary-visible');
            secondaryVideo.style.display = 'block';
            secondaryVideo.style.visibility = 'visible';
            secondaryVideo.style.opacity = '1';
            try { await secondaryVideo.play(); } catch(e) {}
        } else {
            localVideo.srcObject = stream;
            localVideo.muted = true; // Mute local video to prevent echo
            localVideo.autoplay = true; // Ensure autoplay
            localVideo.playsInline = true; // Ensure plays inline on mobile
            // Force play with error handling
            try {
                await localVideo.play();
            } catch (playError) {
                console.warn('Auto-play failed, user may need to interact:', playError);
            }
            localVideo.style.display = 'block';
            secondaryVideo.style.display = 'none';
            remoteVideos.style.display = 'none';
        }
        updateVideoMirroring();

        console.log('Enhanced WebView camera initialized successfully');
        statusBar.textContent = 'High-quality camera ready';

        // Log enhanced stream details for debugging
        const videoTrack = stream.getVideoTracks()[0];
        const audioTrack = stream.getAudioTracks()[0];
        if (videoTrack) {
            const settings = videoTrack.getSettings();
            console.log('Enhanced video track settings:', settings);
        }
        if (audioTrack) {
            const settings = audioTrack.getSettings();
            console.log('Enhanced audio track settings:', settings);
        }

    } catch (err) {
        console.error('Failed to initialize WebView camera:', err);

        // Try fallback constraints
        if (err.name === 'OverconstrainedError' || err.name === 'ConstraintNotSatisfiedError') {
            console.log('Trying fallback camera constraints...');
            try {
                const fallbackConstraints = {
                    video: { facingMode: 'user' },
                    audio: true
                };
                const stream = await navigator.mediaDevices.getUserMedia(fallbackConstraints);
                localStream = stream;
                localVideo.srcObject = stream;
                localVideo.muted = true;
                localVideo.autoplay = true;
                localVideo.playsInline = true;
                localVideo.style.display = 'block';
                secondaryVideo.style.display = 'none';
                remoteVideos.style.display = 'none';
                if (isMicMuted && stream.getAudioTracks().length) {
                    stream.getAudioTracks().forEach(t => t.enabled = false);
                }
                updateVideoMirroring();
                console.log('WebView camera initialized with fallback constraints');
                statusBar.textContent = 'Camera ready (fallback mode)';
            } catch (fallbackErr) {
                console.error('Fallback camera constraints also failed:', fallbackErr);
                statusBar.textContent = 'Error: Camera access failed';
            }
        } else {
            statusBar.textContent = 'Error: Camera/Mic access denied';
        }
    }
};
window.initializeLocalStream = initializeLocalStream;

// Initialize camera on page load (with retry for iOS WebView permission timing)
function startLocalStreamWithRetry(retryCount) {
    retryCount = retryCount || 0;
    const maxRetries = 3;
    initializeLocalStream().catch(function(err) {
        console.warn('initializeLocalStream failed (attempt ' + (retryCount + 1) + '):', err.name, err.message);
        if (retryCount < maxRetries) {
            console.log('Retrying in 800ms...');
            setTimeout(function() { startLocalStreamWithRetry(retryCount + 1); }, 800);
        }
    });
}
window.startLocalStreamWithRetry = startLocalStreamWithRetry;

// Delay first attempt so native iOS can request camera/mic before WebView calls getUserMedia (shorter on iOS so camera is ready before call connects)
const isIOS = /iPad|iPhone|iPod|Mac/.test(navigator.userAgent);
setTimeout(function() { startLocalStreamWithRetry(0); }, isIOS ? 600 : 1200);

function updateVideoMirroring(retryCount = 3) {
    const isSelfie = currentFacingMode === 'user';
    console.log('Updating video mirroring: isSelfie =', isSelfie);

    const peerCount = Object.keys(peers).length;
    const isLocalVideoFullScreenRemote = (peerCount === 1 && localVideo.srcObject !== localStream);

    const localVideoElements = [
        { element: localVideo, name: 'localVideo' },
        { element: secondaryVideo, name: 'secondaryVideo' },
        { element: document.querySelector('.remote-video[data-peer-id="local"] video'), name: 'localVideoClone' }
    ];

    let shouldRetry = false;

    localVideoElements.forEach(({ element, name }) => {
        if (element) {
            let shouldMirror = isSelfie;
            if (name === 'localVideo' && isLocalVideoFullScreenRemote) {
                shouldMirror = false;
                console.log('Skipping mirror on localVideo (it is showing remote participant in 2-user mode)');
            }

            const isCurrentlyMirrored = element.classList.contains('mirrored');
            if (shouldMirror && !isCurrentlyMirrored) {
                element.classList.add('mirrored');
                console.log(`Added mirrored class to ${name}`);
            } else if (!shouldMirror && isCurrentlyMirrored) {
                element.classList.remove('mirrored');
                console.log(`Removed mirrored class from ${name}`);
            }
        } else if (name === 'localVideoClone' && peerCount >= 2 && retryCount > 0) {
            console.warn('Local video clone not found, retrying...');
            shouldRetry = true;
        }
    });

    document.querySelectorAll('.remote-video:not([data-peer-id="local"]) video').forEach(video => {
        if (video.classList.contains('mirrored')) {
            video.classList.remove('mirrored');
            console.log('Removed mirrored class from remote video');
        }
    });

    if (shouldRetry) {
        setTimeout(() => updateVideoMirroring(retryCount - 1), 100);
    }
}

peer.on('open', id => {
    // Clear connection timeout since we connected successfully
    if (connectionTimeout) {
        clearTimeout(connectionTimeout);
        connectionTimeout = null;
    }
    
    myPeerId = id;
    statusBar.textContent = `Connected as: ${id}`;
    // Re-check WiFi status for logging (may have changed)
    const currentWifiStatus = isWifiConnected();
    const currentIceServers = getIceServers();
    const currentServer = hasFallenBack ? FALLBACK_PEER_SERVER : PUBLIC_PEER_SERVER;
    console.log('========================================');
    console.log('[PeerJS Connection] === PEERJS CONNECTION ESTABLISHED ===');
    console.log('[PeerJS Connection] Peer connection opened with ID:', id);
    console.log('[PeerJS Connection] Using server:', currentServer, hasFallenBack ? '(fallback)' : '(public)');
    console.log('[PeerJS Connection] Current WiFi Status:', currentWifiStatus);
    console.log('[PeerJS Connection] ICE Servers Count:', currentIceServers.length);
    console.log('[PeerJS Connection] Using public STUN/TURN servers for NAT traversal');
    console.log('========================================');
    if (typeof Android !== 'undefined') {
        Android.sendPeerId(id);
    }
    reinitializeLocalStream(); // This may reinitialize if needed, but stream should already be available
    // No need to getUserMedia here since it's done early
});

peer.on('call', call => {
    console.log('Received call from peer:', call.peer);
    const needsVideo = !localStream || localStream.getVideoTracks().length === 0;
    const needsStream = !localStream || localStream.getTracks().length === 0 || localStream.getTracks().every(track => !track.enabled || track.readyState !== 'live');
    if (needsVideo || needsStream) {
        // Use enhanced constraints for WebView camera
        const constraints = getOptimalCameraConstraints();
        constraints.video.facingMode = currentFacingMode;

        navigator.mediaDevices.getUserMedia(constraints)
            .then(stream => {
                localStream = stream;
                localVideo.muted = true;
                localVideo.autoplay = true;
                localVideo.playsInline = true;
                console.log('Local stream set for answering call');
                call.answer(stream);
                peers[call.peer] = { call, remoteStream: null };
                setupCallStreamListener(call);
                updateVideoLayout(); // Decides: no remote yet => localVideo = my video; when remote arrives => localVideo = receiver
                updateVideoMirroring();
            })
            .catch(err => {
                console.error('Failed to get local stream for call:', err);
                statusBar.textContent = 'Error: Camera/Mic access denied';
            });
    } else {
        // Ensure tracks match mute/camera state (don't force-enable and overwrite mute)
        localStream.getTracks().forEach(track => {
            if (track.kind === 'video') track.enabled = isCameraOn;
            else if (track.kind === 'audio') track.enabled = !isMicMuted;
        });
        call.answer(localStream);
        console.log('Answering call with existing local stream');
        peers[call.peer] = { call, remoteStream: null };
        setupCallStreamListener(call);
        updateVideoLayout();
        updateVideoMirroring();
    }
});

peer.on('connection', conn => {
    conn.on('data', data => {
        console.log('Received connection data:', data);
        handleSignalingData(data);
    });
    conn.on('error', err => {
        console.error('Connection error with peer:', conn.peer, err);
        statusBar.textContent = `Connection error with ${conn.peer}`;
    });
});

function setRoomId(id) {
    roomId = id;
    console.log('Room ID set to:', id);
}

function handleSignalingData(data) {
    const type = data.type;
    const sender = data.sender;
    console.log('Received signaling data:', data);
    if (type === 'offer' && !peers[sender]) {
        const needsVideo = !localStream || localStream.getVideoTracks().length === 0;
        const needsStream = !localStream || localStream.getTracks().length === 0 || localStream.getTracks().every(track => !track.enabled || track.readyState !== 'live');
        if (needsVideo || needsStream) {
            // Use enhanced constraints for WebView camera
            const constraints = getOptimalCameraConstraints();
            constraints.video.facingMode = currentFacingMode;

            navigator.mediaDevices.getUserMedia(constraints)
                .then(stream => {
                    localStream = stream;
                    localVideo.muted = true;
                    localVideo.autoplay = true;
                    localVideo.playsInline = true;
                    console.log('Local stream set for offer');
                    const call = peer.call(sender, stream);
                    peers[sender] = { call, remoteStream: null };
                    setupCallStreamListener(call);
                    updateVideoLayout();
                    updateVideoMirroring();
                    const conn = peer.connect(sender);
                    conn.on('open', () => {
                        conn.send({ type: 'answer', sender: myPeerId, receiver: sender });
                    });
                })
                .catch(err => {
                    console.error('Failed to get local stream for offer:', err);
                    statusBar.textContent = 'Error: Camera/Mic access denied';
                });
        } else {
            // Ensure tracks match mute/camera state (don't force-enable and overwrite mute)
            localStream.getTracks().forEach(track => {
                if (track.kind === 'video') track.enabled = isCameraOn;
                else if (track.kind === 'audio') track.enabled = !isMicMuted;
            });
            const call = peer.call(sender, localStream);
            console.log('Calling peer with existing local stream:', sender);
            peers[sender] = { call, remoteStream: null };
            setupCallStreamListener(call);
            updateVideoLayout();
            updateVideoMirroring();
            const conn = peer.connect(sender);
            conn.on('open', () => {
                conn.send({ type: 'answer', sender: myPeerId, receiver: sender });
            });
        }
    } else if (type === 'answer' && peers[sender]) {
        console.log('Received answer from peer:', sender);
    } else if (type === 'endCall' && sender !== myPeerId) {
        console.log('Received end call signal from peer:', sender);
        endCall();
    }
}

function updatePeers(data) {
    const peerList = data.peers;
    console.log('Updating peers:', peerList);
    const maxPeers = 3;
    peerList.forEach(peerId => {
        if (peerId !== myPeerId && !peers[peerId] && Object.keys(peers).length < maxPeers) {
            connectToPeer(peerId);
        }
    });
    updateVideoLayout();
}

function connectToPeer(peerId, retries = 3, delay = 5000) {
    console.log('Connecting to peer:', peerId, 'Attempts left:', retries);
    const needsVideo = !localStream || localStream.getVideoTracks().length === 0;
    const needsStream = !localStream || localStream.getTracks().length === 0 || localStream.getTracks().every(track => !track.enabled || track.readyState !== 'live');
    if (needsVideo || needsStream) {
        // Use enhanced constraints for WebView camera
        const constraints = getOptimalCameraConstraints();
        constraints.video.facingMode = currentFacingMode;

        navigator.mediaDevices.getUserMedia(constraints)
            .then(stream => {
                localStream = stream;
                localVideo.muted = true;
                localVideo.autoplay = true;
                localVideo.playsInline = true;
                const call = peer.call(peerId, stream);
                peers[peerId] = { call, remoteStream: null };
                setupCallStreamListener(call);
                updateVideoLayout(); // No remote yet => localVideo = my video; when remote arrives => localVideo = receiver
                updateVideoMirroring();
                const conn = peer.connect(peerId);
                conn.on('open', () => {
                    conn.send({ type: 'offer', sender: myPeerId, receiver: peerId });
                });
            })
            .catch(err => {
                console.error('Failed to get local stream for peer:', err);
                if (retries > 0) {
                    setTimeout(() => connectToPeer(peerId, retries - 1, delay), delay);
                } else {
                    statusBar.textContent = `Failed to connect to peer: ${peerId}`;
                }
            });
    } else {
        // Ensure tracks match mute/camera state (don't force-enable and overwrite mute)
        localStream.getTracks().forEach(track => {
            if (track.kind === 'video') track.enabled = isCameraOn;
            else if (track.kind === 'audio') track.enabled = !isMicMuted;
        });
        const call = peer.call(peerId, localStream);
        console.log('Calling peer with existing local stream:', peerId);
        peers[peerId] = { call, remoteStream: null };
        setupCallStreamListener(call);
        updateVideoLayout();
        updateVideoMirroring();
        const conn = peer.connect(peerId);
        conn.on('open', () => {
            conn.send({ type: 'offer', sender: myPeerId, receiver: peerId });
        });
    }
}

function setupCallStreamListener(call) {
    call.on('stream', remoteStream => {
        console.log('Received remote stream from peer:', call.peer);
        if (remoteStream) {
            peers[call.peer].remoteStream = remoteStream;
            // Apply connected layout: remote → primary, local → secondary.
            // Do NOT call updateVideoLayout() here — it clears localVideo.srcObject first
            // which causes local video to flash on primary before remote is re-assigned.
            applyConnectedLayout(call.peer, remoteStream);
            switchVideos(call.peer, remoteStream);
            updateVideoMirroring();
            // Single delayed retry to ensure streams are fully attached
            setTimeout(function() {
                applyConnectedLayout(call.peer, remoteStream);
                updateVideoMirroring();
            }, 500);
            
            if (Object.keys(peers).length > 0 && typeof Android !== 'undefined') {
                Android.onCallConnected();
            }
        } else {
            console.warn('Received null or undefined stream from peer:', call.peer);
            statusBar.textContent = `No stream from peer ${call.peer}`;
        }
    });
    call.on('close', () => {
        console.log('Call closed with peer:', call.peer);
        delete peers[call.peer];
        updateVideoLayout();
        updateVideoMirroring();
    });
    call.on('error', err => {
        console.error('Call error with peer:', call.peer, err);
        statusBar.textContent = `Error with peer ${call.peer}: ${err.type}`;
    });
}

function switchVideos(peerId, remoteStream) {
    console.log('Switching videos for peer:', peerId);
    const existingVideo = document.querySelector(`.remote-video[data-peer-id="${peerId}"]`);
    if (!existingVideo && remoteStream) {
        let container = document.createElement('div');
        container.className = 'remote-video';
        container.setAttribute('data-peer-id', peerId);
        const video = document.createElement('video');
        video.autoplay = true;
        video.playsInline = true;
        video.poster = "bg_blur.webp";
        video.srcObject = remoteStream;

        video.onloadedmetadata = () => {
            console.log('Remote video metadata loaded for peer:', peerId);
            video.play().catch(err => {
                console.error('Error playing remote video for peer:', peerId, err);
                statusBar.textContent = `Error playing video for peer ${peerId}`;
                video.poster = "bg_blur.webp";
            });
        };
        container.appendChild(video);
        remoteVideos.appendChild(container);
    } else if (existingVideo && remoteStream) {
        const video = existingVideo.querySelector('video');
        video.srcObject = remoteStream;
        video.classList.remove('mirrored');
        video.play().catch(err => {
            console.error('Error playing existing video for peer:', peerId, err);
            statusBar.textContent = `Error playing video for peer ${peerId}`;
        });
    } else {
        console.warn('No valid stream for peer:', peerId);
        let container = document.createElement('div');
        container.className = 'remote-video';
        container.setAttribute('data-peer-id', peerId);
        container.style.background = "url('bg_blur.webp') center center / cover no-repeat";
        remoteVideos.appendChild(container);
    }
    updateVideoMirroring();
}

function updateRemotePoster(videoElement) {
    if (videoElement.poster) {
        // Save current poster for later use
        lastPosters.set(videoElement, videoElement.poster);
    } else {
        // Use last saved poster if available
        if (lastPosters.has(videoElement)) {
            videoElement.poster = lastPosters.get(videoElement);
        } else {
            videoElement.poster = "bg_blur.webp";
            lastPosters.set(videoElement, videoElement.poster);
        }
    }
}

/** When call is connected: force primary (localVideo) = RECEIVER, secondary = MY video. Call after remote stream arrives. */
function applyConnectedLayout(peerId, remoteStream) {
    if (!remoteStream || !peerId) return;
    localVideo.srcObject = null;
    localVideo.srcObject = remoteStream;
    localVideo.muted = false;
    localVideo.playsInline = true;
    localVideo.autoplay = true;
    localVideo.style.display = 'block';
    localVideo.classList.remove('mirrored');
    localVideo.play().catch(function() {});

    if (localStream) {
        secondaryVideo.classList.add('secondary-visible');
        secondaryVideo.srcObject = null;
        secondaryVideo.srcObject = localStream;
        secondaryVideo.muted = true;
        secondaryVideo.playsInline = true;
        secondaryVideo.autoplay = true;
        secondaryVideo.style.display = 'block';
        secondaryVideo.style.visibility = 'visible';
        secondaryVideo.style.opacity = '1';
        secondaryVideo.style.width = '';
        secondaryVideo.style.height = '';
        secondaryVideo.style.minWidth = '120px';
        secondaryVideo.style.minHeight = '160px';
        secondaryVideo.play().catch(function() {});
    } else {
        secondaryVideo.style.display = 'none';
        secondaryVideo.srcObject = null;
    }
}

/** Call from native when onCallConnected: apply primary=receiver, secondary=my video using current peers. */
function applyConnectedLayoutFromPeers() {
    var ids = Object.keys(peers);
    if (ids.length !== 1 || !localStream) return;
    var peerId = ids[0];
    var remoteStream = peers[peerId] && peers[peerId].remoteStream;
    if (remoteStream) applyConnectedLayout(peerId, remoteStream);
}

function updateVideoLayout() {
    const peerIds = Object.keys(peers);
    const peerCount = peerIds.length;
    console.log('Updating video layout for peer count:', peerCount);

    remoteVideos.classList.remove('three-participants', 'four-participants');
    remoteVideos.style.display = 'none';
    remoteVideos.innerHTML = '';

    if (peerCount === 0) {
        // No peers: show local video on primary, hide secondary
        secondaryVideo.classList.remove('secondary-visible');
        secondaryVideo.style.display = 'none';
        secondaryVideo.srcObject = null;
        localVideo.style.display = 'block';
        if (localStream && isCameraOn) {
            hideLocalBlur();
            localVideo.srcObject = localStream;
            localVideo.playsInline = true;
            localVideo.autoplay = true;
            localVideo.play().catch(function() {}); // iOS: so my video shows before call
        } else {
            showLocalBlur();
            updateLocalPoster(); // Apply blur to localVideo
        }
        localVideo.muted = true;
         callerName.style.display = 'block';
    } else if (peerCount === 1) {
       callerName.style.display = 'block';
        const peerId = peerIds[0];
        const remoteStream = peers[peerId] && peers[peerId].remoteStream;

        if (remoteStream) {
            // Call connected: use applyConnectedLayout which sets remote→primary, local→secondary
            applyConnectedLayout(peerId, remoteStream);
            if (!isCameraOn) {
                applyBlurToSecondaryVideo();
            } else {
                removeBlurFromSecondaryVideo();
            }
        } else {
            // Before connect: localVideo = MY video (sender), no secondary
            // But do NOT overwrite if localVideo already has a remote stream (race condition guard)
            var currentSrc = localVideo.srcObject;
            var hasRemoteOnPrimary = false;
            if (currentSrc && currentSrc !== localStream) {
                // localVideo already has a remote stream from applyConnectedLayout - don't overwrite
                hasRemoteOnPrimary = true;
            }
            if (!hasRemoteOnPrimary) {
                console.warn('No remote stream yet from:', peerId);
                localVideo.style.display = 'block';
                localVideo.srcObject = localStream;
                localVideo.muted = true;
                localVideo.playsInline = true;
                localVideo.autoplay = true;
                if (!isCameraOn) {
                    updateLocalPoster();
                } else if (localStream) {
                    localVideo.play().catch(function() {}); // iOS: so sender sees themselves
                }
                secondaryVideo.style.display = 'none';
                secondaryVideo.srcObject = null;
            }
        }
    } else {
       callerName.style.display = 'none';
        // Grid layout for 3+ participants (unchanged)
        remoteVideos.style.display = 'flex';

        const topRow = document.createElement('div');
        topRow.className = 'top-row';
        const bottomRow = document.createElement('div');
        bottomRow.className = 'bottom-row';

        if (localStream) {
            const localContainer = document.createElement('div');
            localContainer.className = 'remote-video';
            localContainer.setAttribute('data-peer-id', 'local');
            const localVideoClone = document.createElement('video');
            localVideoClone.autoplay = true;
            localVideoClone.playsInline = true;
            localVideoClone.muted = true;
            localVideoClone.srcObject = localStream;

            if (!isCameraOn) {
                localVideoClone.poster = captureBlurFrame(localVideo) || "bg_blur.webp";
            }

            localContainer.appendChild(localVideoClone);
            topRow.appendChild(localContainer);
        }

        let topRowCount = 1;
        peerIds.forEach(peerId => {
            const remoteContainer = document.createElement('div');
            remoteContainer.className = 'remote-video';
            remoteContainer.setAttribute('data-peer-id', peerId);

            const video = document.createElement('video');
            video.autoplay = true;
            video.playsInline = true;

            const remoteStream = peers[peerId].remoteStream;
            if (remoteStream) {
                video.srcObject = remoteStream;
                video.classList.remove('mirrored');
                video.onloadedmetadata = () => {
                    video.play().catch(err => {
                        console.error('Error playing remote video for peer:', peerId, err);
                        statusBar.textContent = `Error playing video for peer ${peerId}`;
                        updateRemotePoster(video);
                    });
                };
            } else {
                console.warn('No remote stream for peer:', peerId);
                updateRemotePoster(video);
            }

            remoteContainer.appendChild(video);
            if (topRowCount < 2) {
                topRow.appendChild(remoteContainer);
                topRowCount++;
            } else {
                bottomRow.appendChild(remoteContainer);
            }
        });

        remoteVideos.appendChild(topRow);
        if (bottomRow.children.length > 0) {
            remoteVideos.appendChild(bottomRow);
        }

        if (peerCount === 2) {
            remoteVideos.classList.add('three-participants');
        } else if (peerCount === 3) {
            remoteVideos.classList.add('four-participants');
        }

        console.log('[Layout] Grid layout with', peerCount + 1, 'participants');
    }

    setTimeout(updateVideoMirroring, 0);
}

function adjustForPiPMode() {
    const peerIds = Object.keys(peers);
    const peerCount = peerIds.length;
    console.log('Adjusting layout for PiP mode, peer count:', peerCount);

    // Reset all video displays
    remoteVideos.classList.remove('three-participants', 'four-participants');
    remoteVideos.style.display = 'none';
    remoteVideos.innerHTML = '';
    localVideo.style.display = 'none';
    localVideo.srcObject = null;
    secondaryVideo.style.display = 'none';
    secondaryVideo.srcObject = null;

    // Reinitialize local stream if necessary
    reinitializeLocalStream();

    if (peerCount === 0) {
        if (localStream) {
            localVideo.style.display = 'block';
            localVideo.srcObject = localStream;
            localVideo.muted = true;
            console.log('[PiP Layout] Showing local video for 1 participant');
        }
    } else if (peerCount === 1) {
        const peerId = peerIds[0];
        const remoteStream = peers[peerId].remoteStream;
        if (remoteStream) {
            localVideo.style.display = 'block';
            localVideo.srcObject = remoteStream;
            localVideo.muted = false;
            localVideo.classList.remove('mirrored');
            console.log('[PiP Layout] Showing remote full screen for peer:', peerId);
        } else if (localStream) {
            localVideo.style.display = 'block';
            localVideo.srcObject = localStream;
            localVideo.muted = true;
            console.log('[PiP Layout] Showing local video due to no remote stream');
        }
        if (localStream) {
            secondaryVideo.srcObject = localStream;
            secondaryVideo.style.display = 'block';
            secondaryVideo.muted = true;
            console.log('[PiP Layout] Showing local as PiP');
        }
    } else {
        remoteVideos.style.display = 'flex';
        const topRow = document.createElement('div');
        topRow.className = 'top-row';
        const bottomRow = document.createElement('div');
        bottomRow.className = 'bottom-row';

        if (localStream) {
            const localContainer = document.createElement('div');
            localContainer.className = 'remote-video';
            localContainer.setAttribute('data-peer-id', 'local');
            const localVideoClone = document.createElement('video');
            localVideoClone.autoplay = true;
            localVideoClone.playsInline = true;
            localVideoClone.muted = true;
            localVideoClone.srcObject = localStream;
            localContainer.appendChild(localVideoClone);
            topRow.appendChild(localContainer);
        }

        let topRowCount = 1;
        peerIds.forEach(peerId => {
            const remoteContainer = document.createElement('div');
            remoteContainer.className = 'remote-video';
            remoteContainer.setAttribute('data-peer-id', peerId);
            const video = document.createElement('video');
            video.autoplay = true;
            video.playsInline = true;
            video.poster = "bg_blur.webp";

            const remoteStream = peers[peerId].remoteStream;
            if (remoteStream) {
                video.srcObject = remoteStream;
                video.classList.remove('mirrored');
                video.onloadedmetadata = () => {
                    video.play().catch(err => {
                        console.error('Error playing remote video for peer:', peerId, err);
                        statusBar.textContent = `Error playing video for peer ${peerId}`;
                        video.poster = "bg_blur.webp";
                    });
                };
            }
            remoteContainer.appendChild(video);
            if (topRowCount < 2) {
                topRow.appendChild(remoteContainer);
                topRowCount++;
            } else {
                bottomRow.appendChild(remoteContainer);
            }
        });

        remoteVideos.appendChild(topRow);
        if (bottomRow.children.length > 0) {
            remoteVideos.appendChild(bottomRow);
        }

        if (peerCount === 2) {
            remoteVideos.classList.add('three-participants');
        } else if (peerCount === 3) {
            remoteVideos.classList.add('four-participants');
        }
        console.log('[PiP Layout] Showing grid layout for', peerCount + 1, 'participants');
    }

    setTimeout(() => {
        updateVideoLayout();
        updateVideoMirroring();
    }, 0);
}

/** Theme color for mute button (used in both states so button always shows theme) */
function getMuteButtonThemeColor() {
    const theme = getComputedStyle(document.documentElement).getPropertyValue('--theme-color').trim();
    return (theme && theme !== '') ? theme : '#00A3E9';
}

/** Update mute button appearance to match isMicMuted; always use theme color so button is visible */
function updateMuteButtonUI() {
    if (!muteMicBtn) return;
    const themeColor = getMuteButtonThemeColor();
    if (isMicMuted) {
        muteMicBtn.classList.add('muted');
        muteMicBtn.title = 'Unmute Mic';
        muteMicBtn.style.backgroundColor = themeColor;
        muteMicBtn.style.opacity = '0.9';
    } else {
        muteMicBtn.classList.remove('muted');
        muteMicBtn.title = 'Mute Mic';
        muteMicBtn.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
        muteMicBtn.style.opacity = '1';
    }
}

/** Apply mute state (e.g. from native when page loads). Muted = true means mic is off. */
function applyInitialMuteState(muted) {
    isMicMuted = !!muted;
    if (localStream && localStream.getAudioTracks().length) {
        localStream.getAudioTracks().forEach(t => t.enabled = !isMicMuted);
        console.log('Applied initial mute state to WebRTC:', isMicMuted);
    }
    updateMuteButtonUI();
    if (typeof Android !== 'undefined') {
        try {
            if (Android.toggleMicrophone) Android.toggleMicrophone(isMicMuted);
            if (Android.saveMuteState) Android.saveMuteState(isMicMuted);
        } catch (err) {
            console.warn('applyInitialMuteState: Android bridge error', err);
        }
    }
}

muteMicBtn.addEventListener('click', () => {
    isMicMuted = !isMicMuted;
    const enableAudio = !isMicMuted;

    // 1) Mute voice immediately: local stream audio tracks
    if (localStream) {
        const audioTracks = localStream.getAudioTracks ? localStream.getAudioTracks() : [];
        for (let i = 0; i < audioTracks.length; i++) {
            audioTracks[i].enabled = enableAudio;
        }
        if (audioTracks.length) console.log('WebRTC Microphone muted:', isMicMuted, 'localStream audio tracks:', audioTracks.length);
    }

    // 2) Mute audio on every peer connection (tracks actually being sent to remote)
    Object.values(peers).forEach(p => {
        if (p.call && p.call.peerConnection) {
            try {
                const senders = p.call.peerConnection.getSenders();
                senders.forEach(s => {
                    if (s.track && s.track.kind === 'audio') {
                        s.track.enabled = enableAudio;
                    }
                });
            } catch (e) { console.warn('Mute: peer senders error', e); }
        }
    });

    // 3) Update button (theme color when muted, transparent when unmuted)
    updateMuteButtonUI();

    // 4) Notify native (iOS/Android)
    if (typeof Android !== 'undefined') {
        try {
            if (Android.toggleMicrophone) Android.toggleMicrophone(isMicMuted);
            if (Android.saveMuteState) Android.saveMuteState(isMicMuted);
        } catch (err) {
            console.error('Failed to call Android.toggleMicrophone:', err);
        }
    }
});

toggleCameraBtn.addEventListener('click', () => {
    isCameraOn = !isCameraOn;
    console.log('Camera toggled:', isCameraOn ? 'On' : 'Off');
    if (localStream) {
        if (!isCameraOn) {
            // ✅ Capture blur frame from secondary_video BEFORE disabling camera
            if (secondaryVideo && secondaryVideo.videoWidth > 0 && secondaryVideo.readyState >= 2) {
                const blurDataUrl = captureBlurFrame(secondaryVideo);
                if (blurDataUrl) {
                    lastLocalBlur = blurDataUrl;
                    console.log('Captured blur frame from secondary_video before pausing camera');
                }
            }

            toggleCameraBtn.classList.add('muted');
            toggleCameraBtn.style.backgroundColor = getComputedStyle(document.documentElement).getPropertyValue('--theme-color').trim() || '#00A3E9';
            toggleCameraBtn.style.opacity = '0.7';
            localStream.getVideoTracks().forEach(t => t.enabled = false);
            applyBlurToSecondaryVideo(); // Apply blur to secondaryVideo
            replaceLocalVideoWithBlur(); // Send blurred stream to peers
            updateLocalPoster(); // Apply blur to localVideo
        } else {
            toggleCameraBtn.classList.remove('muted');
            toggleCameraBtn.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
            toggleCameraBtn.style.opacity = '1';
            localStream.getVideoTracks().forEach(t => t.enabled = true);
            secondaryVideo.srcObject = localStream;
            removeBlurFromSecondaryVideo(); // Remove blur from secondaryVideo
            Object.values(peers).forEach(p => {
                if (p.call) {
                    const sender = p.call.peerConnection.getSenders().find(s => s.track && s.track.kind === 'video');
                    if (sender) {
                        sender.replaceTrack(localStream.getVideoTracks()[0]);
                        console.log('Restored live video track for peer:', p.call.peer);
                    }
                }
            });
            hideLocalBlur(); // Remove blur from localVideo
        }
        updateVideoLayout();
        updateVideoMirroring();
    }
});


switchCameraBtn.addEventListener('click', () => {
    if (!localStream) return;

    const newFacingMode = currentFacingMode === 'user' ? 'environment' : 'user';
    console.log('Switching camera to:', newFacingMode);

    localStream.getVideoTracks().forEach(track => track.stop());

    // Use enhanced constraints for WebView camera
    const constraints = getOptimalCameraConstraints();
    constraints.video.facingMode = newFacingMode;

    navigator.mediaDevices.getUserMedia(constraints)
        .then(newStream => {
            localStream = newStream;
            currentFacingMode = newFacingMode;

            secondaryVideo.srcObject = newStream;
            const localVideoClone = document.querySelector('.remote-video[data-peer-id="local"] video');
            if (localVideoClone) {
                localVideoClone.srcObject = newStream;
                console.log('Updated local video clone with new stream');
            }
            // Do not set localVideo.srcObject here – updateVideoLayout() sets localVideo = receiver when connected, secondary = my video

            Object.values(peers).forEach(peer => {
                const sender = peer.call.peerConnection.getSenders().find(s => s.track && s.track.kind === 'video');
                if (sender) {
                    const videoTrack = newStream.getVideoTracks()[0];
                    sender.replaceTrack(videoTrack);
                    console.log('Replaced video track for peer:', peer.call.peer);
                }
            });

            if (currentFacingMode === 'environment') {
                switchCameraBtn.style.backgroundColor = getComputedStyle(document.documentElement)
                    .getPropertyValue('--theme-color').trim() || '#00A3E9';
                switchCameraBtn.style.opacity = '0.7';
            } else {
                switchCameraBtn.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                switchCameraBtn.style.opacity = '1';
            }

            updateVideoLayout();
            updateVideoMirroring();
        })
        .catch(err => {
            console.error('Failed to switch camera:', err);
            statusBar.textContent = 'Error: Failed to switch camera';
        });
});

function endCall() {
    console.log('Ending call');
    if (localStream) localStream.getTracks().forEach(track => track.stop());
    Object.values(peers).forEach(peer => peer.call.close());
    peer.destroy();
    if (typeof Android !== 'undefined') {
        Android.endCall();
    }
}

endCallBtn.addEventListener('click', () => {
    console.log('End call button clicked');
    const peerCount = Object.keys(peers).length + 1; // Including local user
    console.log('Total participants:', peerCount);

    if (peerCount === 2 && Object.keys(peers).length > 0) {
        const otherPeerId = Object.keys(peers)[0];
        const conn = peer.connect(otherPeerId);
        conn.on('open', () => {
            conn.send({ type: 'endCall', sender: myPeerId, receiver: otherPeerId });
            console.log('Sent endCall signal to peer:', otherPeerId);
          //  endCall();
        });
         endCall();
    } else {
        endCall();
    }
});

peer.on('error', err => {
    console.error('Peer error:', err);
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
        statusBar.textContent = `Error: ${err.type}`;
    }
});

document.addEventListener("DOMContentLoaded", () => {
    // Show muted state on load (default is muted)
    updateMuteButtonUI();

    // Notify native (iOS/Android) that page is ready so it can send roomId, theme, and initial mute state
    if (typeof Android !== 'undefined' && Android.onPageReady) {
        try { Android.onPageReady(); } catch (e) { console.warn('onPageReady failed', e); }
    }

    const backBtn = document.getElementById('backBtn');
    const addMemberBtn = document.getElementById('addMemberBtn');
    const pipButton = document.getElementById('pipButton');
    const videoContainer = document.querySelector(".video-container");
    const controlsContainer = document.querySelector(".controls-container");
    const topBar = document.querySelector(".top-bar");
    const secondaryVideo = document.querySelector(".secondary-video");

    controlsContainer.classList.add("hidden");
    topBar.classList.add("hidden");
    secondaryVideo.classList.add("compact");


      if (secondaryVideo) {
        secondaryVideo.style.display = "none";
      }

    videoContainer.addEventListener("click", (event) => {
        if (event.target.closest(".control-btn") || event.target.closest(".top-btn")) return;
        controlsContainer.classList.toggle("hidden");
        topBar.classList.toggle("hidden");
        const isControlsHidden = controlsContainer.classList.contains("hidden");
        if (isControlsHidden) {
            secondaryVideo.classList.add("compact");
        } else {
            secondaryVideo.classList.remove("compact");
        }
    });

    if (backBtn) {
        backBtn.addEventListener('click', () => {
            console.log('Back button clicked');
            if (typeof Android !== 'undefined') {
//                backBtn.style.backgroundColor = getComputedStyle(document.documentElement)
//                    .getPropertyValue('--theme-color').trim() || '#ff0000';
                Android.enterPiPModes();
                adjustForPiPMode();
            } else {
                console.warn('Android interface not available');
                statusBar.textContent = 'Error: Cannot enter PiP mode';
            }
        });
    } else {
        console.error('Back button not found');
    }

    if (addMemberBtn) {
        addMemberBtn.addEventListener('click', () => {
            console.log('Add member button clicked');
            if (typeof Android !== 'undefined') {
                addMemberBtn.style.backgroundColor = getComputedStyle(document.documentElement)
                    .getPropertyValue('--theme-color').trim() || '#00A3E9';
                Android.addMemberBtn();
            } else {
                console.warn('Android interface not available');
                statusBar.textContent = 'Error: Cannot add member';
            }
        });
    } else {
        console.error('Add member button not found');
    }

    if (pipButton) {
        pipButton.addEventListener('click', () => {
            console.log('PiP button clicked');
            if (typeof Android !== 'undefined') {
                pipButton.style.backgroundColor = getComputedStyle(document.documentElement)
                    .getPropertyValue('--theme-color').trim() || '#00A3E9';
                Android.enterPiPModes();
                adjustForPiPMode();
            } else {
                console.warn('Android interface not available for PiP mode');
                statusBar.textContent = 'Error: PiP mode not supported';
            }
        });
    } else {
        console.error('PiP button not found');
    }
});

function setThemeColor(hexColor) {
    document.documentElement.style.setProperty('--theme-color', hexColor);
}

function setRemoteCallerInfo(photo, name) {
    remoteCallerPhoto = photo;
    remoteCallerName = name;
    callerName.textContent = name;
    console.log("Remote caller info set:", remoteCallerPhoto, remoteCallerName);

 //   initializeCallerInfo();
}

function initializeCallerInfo() {
    if (!remoteCallerPhoto && !remoteCallerName) return;

    singleCallerInfo.style.display = 'flex';
    gridContainer.style.display = 'none';

    const photo = remoteCallerPhoto || 'user.png';
    const name = remoteCallerName || 'Name';

    singleCallerInfo.innerHTML = `
        <img id="callerImage" src="${photo}" alt="${name}" style="border-radius: 50%; width: 100px; height: 100px;">
        <div id="callerName" class="caller-name">${name}</div>
    `;
    singleCallerInfo.appendChild(callTimer);
    singleCallerInfo.appendChild(callStatus);
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
    console.log("📶 Network restored");
    const callStatus = document.getElementById('callStatus');
    if (callStatus) {
        callStatus.textContent = "Connected";
    }
    if (isDisconnected) {
        isDisconnected = false;
        reconnectPeer();
        reinitializeLocalStream();
        if (typeof applyConnectedLayoutFromPeers === 'function') applyConnectedLayoutFromPeers();
        updateVideoMirroring();
    }
    sendStatusToPeers("Connected");
}


function reconnectPeer() {
    console.log("Attempting to reconnect PeerJS...");
    if (peer && !peer.destroyed) {
        peer.reconnect();
        Object.values(peers).forEach(peer => {
            if (peer.call && localStream) {
                const sender = peer.call.peerConnection.getSenders().find(s => s.track && s.track.kind === 'video');
                if (sender) {
                    const videoTrack = localStream.getVideoTracks()[0];
                    sender.replaceTrack(videoTrack).then(() => {
                        console.log('Replaced video track for peer:', peer.call.peer);
                        hideLocalBlur(); // stream active असल्यास blur काढ
                        if (typeof applyConnectedLayoutFromPeers === 'function') applyConnectedLayoutFromPeers();
                        updateVideoMirroring();
                    }).catch(err => {
                        console.error('Error replacing video track:', err);
                        showLocalBlur(); // error झाल्यास blur लाव
                    });
                }
            }
        });
    } else {
        recreatePeer();
    }
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
    
    console.log('========================================');
    console.log('[PeerJS Reconnect] === PEERJS RECONNECTION CONFIGURATION ===');
    console.log('[PeerJS Reconnect] WiFi Connected:', currentWifiStatus);
    const currentPeerServerUrl = `${PEER_SECURE ? 'https' : 'http'}://${reconnectServer}:${PEER_PORT}${PEER_PATH}`;
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
    console.log('[PeerJS Reconnect] ICE Candidate Pool Size: 10');
    console.log('[PeerJS Reconnect] Previous Peer ID:', myPeerId);
    console.log('========================================');

    console.log('[PeerJS Reconnect] Destroying previous peer instance...');
    if (peer && !peer.destroyed) {
        try {
            peer.destroy();
            console.log('[PeerJS Reconnect] Previous peer destroyed successfully');
        } catch (e) {
            console.warn('[PeerJS Reconnect] Error destroying previous peer:', e);
        }
    }
    
    console.log('[PeerJS Reconnect] Creating new peer instance with ID:', myPeerId || 'undefined');
    peer = new Peer(myPeerId || undefined, {
        host: reconnectServer,
        port: PEER_PORT,
        path: PEER_PATH,
        secure: PEER_SECURE,
        config: {
            iceServers: currentIceServers,
            iceCandidatePoolSize: 10
        },
        debug: 3
    });
    console.log('[PeerJS Reconnect] New peer instance created successfully');
    console.log('========================================');
    initPeer(myPeerId);
    // Rest of the function remains unchanged
    if (!localStream) {
        // Use enhanced constraints for WebView camera
        const constraints = getOptimalCameraConstraints();
        constraints.video.facingMode = currentFacingMode;

        navigator.mediaDevices.getUserMedia(constraints)
            .then(stream => {
                localStream = stream;
                if (typeof applyConnectedLayoutFromPeers === 'function') applyConnectedLayoutFromPeers();
                updateVideoMirroring();
                console.log('Local stream reinitialized');
                Object.keys(peers).forEach(peerId => {
                    connectToPeer(peerId);
                });
            })
            .catch(err => {
                console.error('Failed to reinitialize local stream:', err);
                statusBar.textContent = 'Error: Camera/Mic access denied';
            });
    }
}

function callUser(peerId) {
    if (!localStream) return;
    const call = peer.call(peerId, localStream);
    call.on('stream', remoteStream => {
        addAudioStream(peerId, remoteStream); // Attach remote audio
    });
    call.on('close', () => {
        console.log("Call closed with", peerId);
        removeAudioStream(peerId);
    });
    call.on('error', err => {
        console.error("Call error:", err);
    });
    peers[peerId] = call;
}

function initPeer(uid) {
    peer.id = uid;

    peer.on('open', id => {
        const currentWifiStatus = isWifiConnected();
        const currentIceServers = getIceServers();
        console.log("✅ PeerJS connected with ID:", id);
        console.log('[PeerJS Connection] WiFi Status:', currentWifiStatus);
        console.log('[PeerJS Connection] ICE Servers Count:', currentIceServers.length);
    });

    peer.on('call', call => {
        call.answer(localStream);

        call.on('stream', remoteStream => {
            addAudioStream(call.peer, remoteStream);
        });

        call.on('close', () => {
            console.log("Call closed with", call.peer);
            removeAudioStream(call.peer);
        });

        peers[call.peer] = call;
    });

    peer.on('error', err => {
        console.error("Peer error:", err);
    });

    peer.on('disconnected', () => {
        console.warn("PeerJS disconnected");
    });

    peer.on('close', () => {
        console.warn("PeerJS closed");
    });
}

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

function reinitializeLocalStream() {
    if (!localStream || localStream.getTracks().every(track => !track.enabled)) {
        // Use enhanced constraints for WebView camera
        const constraints = getOptimalCameraConstraints();
        constraints.video.facingMode = currentFacingMode;

        navigator.mediaDevices.getUserMedia(constraints)
            .then(stream => {
                localStream = stream;
                stream.getAudioTracks().forEach(t => { t.enabled = !isMicMuted; });
                secondaryVideo.srcObject = stream;
                const localVideoClone = document.querySelector('.remote-video[data-peer-id="local"] video');
                if (localVideoClone) {
                    localVideoClone.srcObject = stream;
                }
                Object.values(peers).forEach(peer => {
                    if (!peer.call || !peer.call.peerConnection) return;
                    const senders = peer.call.peerConnection.getSenders();
                    senders.forEach(s => {
                        if (!s.track) return;
                        if (s.track.kind === 'video') {
                            const videoTrack = stream.getVideoTracks()[0];
                            if (videoTrack) s.replaceTrack(videoTrack);
                        } else if (s.track.kind === 'audio') {
                            const audioTrack = stream.getAudioTracks()[0];
                            if (audioTrack) {
                                audioTrack.enabled = !isMicMuted;
                                s.replaceTrack(audioTrack);
                            }
                        }
                    });
                });
                // Don't call updateVideoLayout() — it can reset the connected layout.
                // applyConnectedLayoutFromPeers safely sets remote→primary, local→secondary if peers exist.
                if (typeof applyConnectedLayoutFromPeers === 'function') applyConnectedLayoutFromPeers();
                updateVideoMirroring();
                console.log('Local stream reinitialized');
            })
            .catch(err => {
                console.error('Failed to reinitialize local stream:', err);
                statusBar.textContent = 'Error: Camera/Mic access denied';
            });
    }
}


function updateLocalPoster() {
    if (!localVideo) return;

    // Android 15 WebView compatibility check
    const isAndroid15 = /Android 15|API 35/i.test(navigator.userAgent) ||
                       (navigator.userAgent.includes('Android') &&
                        /Chrome\/\d+\.\d+\.\d+\.\d+/.test(navigator.userAgent));

    // Use the pre-captured blur frame from secondary_video if available
    if (lastLocalBlur) {
        localVideo.poster = lastLocalBlur;
        localVideo.srcObject = null;
        localVideo.load(); // Force reload to display poster
        console.log('Applied pre-captured blur from secondary_video to localVideo');
        return;
    }

    // Fallback: try to capture from secondary_video if it has a valid frame
    if (secondaryVideo && secondaryVideo.readyState >= 2 && secondaryVideo.videoWidth > 0) {
        const canvas = document.createElement("canvas");
        canvas.width = secondaryVideo.videoWidth;
        canvas.height = secondaryVideo.videoHeight;
        const ctx = canvas.getContext("2d");

        // Draw blurred frame
        ctx.filter = "blur(15px)";
        ctx.drawImage(secondaryVideo, 0, 0, canvas.width, canvas.height);

        // Dark overlay for better contrast
        ctx.filter = "none"; // Remove blur before overlay
        ctx.fillStyle = "rgba(0,0,0,0.3)";
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Convert to image and set poster
        const blurredImage = canvas.toDataURL("image/png");
        lastLocalBlur = blurredImage; // Save for future use
        localVideo.poster = blurredImage;

        // ✅ Stop showing live video so poster becomes visible
        localVideo.srcObject = null;
        localVideo.load(); // Force reload to display poster
        console.log('Applied captured blur from secondary_video to localVideo');
    } else {
        // Android 15 specific fallback: use default blur with enhanced loading
        if (isAndroid15) {
            console.log('Android 15: Using enhanced blur image loading');
            // Try to preload the blur image to ensure it's available
            const preloadImg = new Image();
            preloadImg.onload = () => {
                localVideo.poster = "bg_blur.webp";
                localVideo.srcObject = null;
                localVideo.load();
                console.log('Android 15: Applied preloaded default blur to localVideo');
            };
            preloadImg.onerror = () => {
                // If blur image fails to load, try again with direct assignment
                console.warn('Android 15: Blur image failed to load, trying direct assignment');
                localVideo.poster = "bg_blur.webp";
                localVideo.srcObject = null;
                localVideo.load();
            };
            preloadImg.src = "bg_blur.webp";
        } else {
            // Final fallback: use default blur
            localVideo.poster = "bg_blur.webp";
            localVideo.srcObject = null;
            localVideo.load();
            console.log('Applied default blur to localVideo');
        }
    }
}
function captureBlurFrame(video) {
    if (!video || video.readyState < 2 || video.videoWidth === 0) return null;

    const canvas = document.createElement("canvas");
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    const ctx = canvas.getContext("2d");
    ctx.filter = "blur(15px)";
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    ctx.filter = "none";
    ctx.fillStyle = "rgba(0,0,0,0.3)";
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    return canvas.toDataURL("image/png");
}

function showLocalBlur() {
    const blurDataUrl = captureBlurFrame(localVideo) || lastLocalBlur;
    if (blurDataUrl) {
        lastLocalBlur = blurDataUrl;
        let blurImg = document.getElementById("localBlurImage");
        if (!blurImg) {
            blurImg = document.createElement("img");
            blurImg.id = "localBlurImage";
            blurImg.style.position = "absolute";
            blurImg.style.top = "0";
            blurImg.style.left = "0";
            blurImg.style.width = "100%";
            blurImg.style.height = "100%";
            blurImg.style.objectFit = "cover";
            blurImg.style.zIndex = "5";
            blurImg.style.background = "url('bg_blur.webp') center center / cover no-repeat";
            localVideo.parentElement.style.position = "relative";
            localVideo.parentElement.appendChild(blurImg);
        }
        blurImg.src = blurDataUrl;
        blurImg.style.display = "block";
        localVideo.style.visibility = "hidden";
    }
}

function hideLocalBlur() {
    const blurImg = document.getElementById("localBlurImage");
    if (blurImg) blurImg.style.display = "none";
    localVideo.style.visibility = "visible";
}

function replaceLocalVideoWithBlur() {
    const blurStream = generateBlurStreamFromLocal();
    if (!blurStream) {
        console.warn('Failed to generate blur stream, skipping track replacement');
        return;
    }

    // Android 15 compatibility: check if stream has video tracks
    if (!blurStream.getVideoTracks || blurStream.getVideoTracks().length === 0) {
        console.warn('Android 15: Blur stream has no video tracks, using alternative approach');
        // For Android 15, we'll rely on the poster image approach instead
        return;
    }

    Object.values(peers).forEach(p => {
        if (p.call) {
            const sender = p.call.peerConnection.getSenders().find(s => s.track && s.track.kind === 'video');
            if (sender) {
                try {
                    sender.replaceTrack(blurStream.getVideoTracks()[0]);
                    console.log('Successfully replaced video track with blur stream for peer:', p.call.peer);
                } catch (error) {
                    console.error('Android 15: Error replacing video track:', error);
                    // Fallback: just disable the video track
                    if (localStream) {
                        localStream.getVideoTracks().forEach(track => track.enabled = false);
                    }
                }
            }
        }
    });
}

function generateBlurStreamFromLocal() {
    // Try to use the last captured blur frame from secondary_video first
    if (lastLocalBlur) {
        return generateBlurStreamFromImageSync(lastLocalBlur);
    }

    // Fallback: try to capture from secondary_video if it has a valid frame
    if (secondaryVideo && secondaryVideo.videoWidth > 0 && secondaryVideo.readyState >= 2) {
        const canvas = document.createElement("canvas");
        canvas.width = secondaryVideo.videoWidth;
        canvas.height = secondaryVideo.videoHeight;
        const ctx = canvas.getContext("2d");

        ctx.filter = "blur(15px)";
        ctx.drawImage(secondaryVideo, 0, 0, canvas.width, canvas.height);
        ctx.filter = "none";
        ctx.fillStyle = "rgba(0,0,0,0.3)";
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Save this blur frame for future use
        const blurDataUrl = canvas.toDataURL("image/png");
        lastLocalBlur = blurDataUrl;

        // Capture as stream
        return canvas.captureStream(5); // 5 FPS enough for static blur
    }

    // Final fallback: use default blur
    return generateBlurStreamFromImageSync("bg_blur.webp");
}

function generateBlurStreamFromImageSync(imageSrc) {
    // Android 15 WebView compatibility check
    const isAndroid15 = /Android 15|API 35/i.test(navigator.userAgent) ||
                       (navigator.userAgent.includes('Android') &&
                        /Chrome\/\d+\.\d+\.\d+\.\d+/.test(navigator.userAgent));

    // For data URLs (base64), we can create the stream directly
    if (imageSrc.startsWith('data:')) {
        const canvas = document.createElement("canvas");
        canvas.width = 640; // Standard video width
        canvas.height = 480; // Standard video height
        const ctx = canvas.getContext("2d");

        const img = new Image();
        img.onload = () => {
            ctx.filter = "blur(15px)";
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            ctx.filter = "none";
            ctx.fillStyle = "rgba(0,0,0,0.3)";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
        };
        img.onerror = () => {
            // Android 15 fallback: use bg_blur.webp
            const fallbackImg = new Image();
            fallbackImg.onload = () => {
                ctx.filter = "blur(15px)";
                ctx.drawImage(fallbackImg, 0, 0, canvas.width, canvas.height);
                ctx.filter = "none";
                ctx.fillStyle = "rgba(0,0,0,0.3)";
                ctx.fillRect(0, 0, canvas.width, canvas.height);
            };
            fallbackImg.src = "bg_blur.webp";
        };
        img.src = imageSrc;

        // Android 15 compatibility: check if captureStream is available
        if (isAndroid15 && typeof canvas.captureStream !== 'function') {
            console.warn('Android 15: canvas.captureStream not available, using fallback');
            return generateAndroid15FallbackStream();
        }

        return canvas.captureStream(5); // 5 FPS enough for static blur
    }

    // For file URLs, use blur_img instead of solid colors
    const canvas = document.createElement("canvas");
    canvas.width = 640;
    canvas.height = 480;
    const ctx = canvas.getContext("2d");

    // Use blur_img as fallback instead of solid colors
    const img = new Image();
    img.onload = () => {
        ctx.filter = "blur(15px)";
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        ctx.filter = "none";
        ctx.fillStyle = "rgba(0,0,0,0.3)";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    };
    img.onerror = () => {
        // If blur_img fails to load, use bg_blur.webp
        const fallbackImg = new Image();
        fallbackImg.onload = () => {
            ctx.filter = "blur(15px)";
            ctx.drawImage(fallbackImg, 0, 0, canvas.width, canvas.height);
            ctx.filter = "none";
            ctx.fillStyle = "rgba(0,0,0,0.3)";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
        };
        fallbackImg.src = "bg_blur.webp";
    };
    img.src = imageSrc;

    // Android 15 compatibility: check if captureStream is available
    if (isAndroid15 && typeof canvas.captureStream !== 'function') {
        console.warn('Android 15: canvas.captureStream not available, using fallback');
        return generateAndroid15FallbackStream();
    }

    return canvas.captureStream(5);
}

// Android 15 fallback stream generator
function generateAndroid15FallbackStream() {
    console.log('Generating Android 15 fallback blur stream using bg_blur.webp');

    // Create a simple MediaStream with a single video track
    const canvas = document.createElement("canvas");
    canvas.width = 640;
    canvas.height = 480;
    const ctx = canvas.getContext("2d");

    // Use bg_blur.webp as background
    const img = new Image();
    img.onload = () => {
        ctx.filter = "blur(15px)";
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        ctx.filter = "none";
        ctx.fillStyle = "rgba(0,0,0,0.3)";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    };
    img.onerror = () => {
        console.warn('Android 15: bg_blur.webp failed to load in fallback stream');
        // If even bg_blur.webp fails, we'll return null
    };
    img.src = "bg_blur.webp";

    // Try to create stream, fallback to null if not supported
    try {
        if (typeof canvas.captureStream === 'function') {
            return canvas.captureStream(5);
        } else {
            console.warn('Android 15: canvas.captureStream not supported, returning null stream');
            return null;
        }
    } catch (error) {
        console.error('Android 15: Error creating fallback stream:', error);
        return null;
    }
}

function generateBlurStreamFromImage(imageSrc) {
    return new Promise((resolve) => {
        // Android 15 WebView compatibility check
        const isAndroid15 = /Android 15|API 35/i.test(navigator.userAgent) ||
                           (navigator.userAgent.includes('Android') &&
                            /Chrome\/\d+\.\d+\.\d+\.\d+/.test(navigator.userAgent));

        const img = new Image();
        img.crossOrigin = "anonymous";
        img.onload = () => {
            const canvas = document.createElement("canvas");
            canvas.width = 640; // Standard video width
            canvas.height = 480; // Standard video height
            const ctx = canvas.getContext("2d");

            // Draw and blur the image
            ctx.filter = "blur(15px)";
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            ctx.filter = "none";
            ctx.fillStyle = "rgba(0,0,0,0.3)";
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            // Android 15 compatibility: check if captureStream is available
            if (isAndroid15 && typeof canvas.captureStream !== 'function') {
                console.warn('Android 15: canvas.captureStream not available in async function');
                resolve(generateAndroid15FallbackStream());
                return;
            }

            // Capture as stream
            const stream = canvas.captureStream(5); // 5 FPS enough for static blur
            resolve(stream);
        };
        img.onerror = () => {
            // Fallback to blur_img instead of solid colors
            const fallbackImg = new Image();
            fallbackImg.onload = () => {
                const canvas = document.createElement("canvas");
                canvas.width = 640;
                canvas.height = 480;
                const ctx = canvas.getContext("2d");
                ctx.filter = "blur(15px)";
                ctx.drawImage(fallbackImg, 0, 0, canvas.width, canvas.height);
                ctx.filter = "none";
                ctx.fillStyle = "rgba(0,0,0,0.3)";
                ctx.fillRect(0, 0, canvas.width, canvas.height);

                // Android 15 compatibility check
                if (isAndroid15 && typeof canvas.captureStream !== 'function') {
                    console.warn('Android 15: canvas.captureStream not available in fallback');
                    resolve(generateAndroid15FallbackStream());
                    return;
                }

                resolve(canvas.captureStream(5));
            };
            fallbackImg.onerror = () => {
                // Final fallback: use bg_blur.webp
                const finalFallbackImg = new Image();
                finalFallbackImg.onload = () => {
                    const canvas = document.createElement("canvas");
                    canvas.width = 640;
                    canvas.height = 480;
                    const ctx = canvas.getContext("2d");
                    ctx.filter = "blur(15px)";
                    ctx.drawImage(finalFallbackImg, 0, 0, canvas.width, canvas.height);
                    ctx.filter = "none";
                    ctx.fillStyle = "rgba(0,0,0,0.3)";
                    ctx.fillRect(0, 0, canvas.width, canvas.height);

                    // Android 15 compatibility check
                    if (isAndroid15 && typeof canvas.captureStream !== 'function') {
                        console.warn('Android 15: canvas.captureStream not available in final fallback');
                        resolve(generateAndroid15FallbackStream());
                        return;
                    }

                    resolve(canvas.captureStream(5));
                };
                finalFallbackImg.onerror = () => {
                    console.error('All blur image fallbacks failed');
                    resolve(null);
                };
                finalFallbackImg.src = "bg_blur.webp";
            };
            fallbackImg.src = "bg_blur.webp";
        };
        img.src = imageSrc;
    });
}

function applyBlurToSecondaryVideo() {
    // Android 15 WebView compatibility check
    const isAndroid15 = /Android 15|API 35/i.test(navigator.userAgent) ||
                       (navigator.userAgent.includes('Android') &&
                        /Chrome\/\d+\.\d+\.\d+\.\d+/.test(navigator.userAgent));

    // Use the pre-captured blur frame from secondary_video if available
    if (lastLocalBlur) {
        secondaryVideo.srcObject = null; // Remove live stream
        secondaryVideo.poster = lastLocalBlur; // Set blurred poster
        secondaryVideo.load(); // Force reload to display poster
        console.log('Applied pre-captured blur from secondary_video to secondaryVideo');
        return;
    }

    // Fallback: try to capture from secondary_video if it has a valid frame
    if (secondaryVideo && secondaryVideo.readyState >= 2 && secondaryVideo.videoWidth > 0) {
        const blurDataUrl = captureBlurFrame(secondaryVideo);
        if (blurDataUrl) {
            lastLocalBlur = blurDataUrl;
            secondaryVideo.srcObject = null; // Remove live stream
            secondaryVideo.poster = blurDataUrl; // Set blurred poster
            secondaryVideo.load(); // Force reload to display poster
            console.log('Applied captured blur from secondary_video to secondaryVideo');
            return;
        }
    }

    // Android 15 specific fallback: use default blur with enhanced loading
    if (isAndroid15) {
        console.log('Android 15: Using enhanced blur image loading for secondary video');
        // Try to preload the blur image to ensure it's available
        const preloadImg = new Image();
        preloadImg.onload = () => {
            secondaryVideo.srcObject = null;
            secondaryVideo.poster = "bg_blur.webp";
            secondaryVideo.load();
            console.log('Android 15: Applied preloaded default blur to secondaryVideo');
        };
        preloadImg.onerror = () => {
            // If blur image fails to load, try again with direct assignment
            console.warn('Android 15: Blur image failed to load for secondary video, trying direct assignment');
            secondaryVideo.srcObject = null;
            secondaryVideo.poster = "bg_blur.webp";
            secondaryVideo.load();
        };
        preloadImg.src = "bg_blur.webp";
    } else {
        // Final fallback: use default blur
        secondaryVideo.srcObject = null;
        secondaryVideo.poster = "bg_blur.webp";
        secondaryVideo.load();
        console.log('Applied default blur to secondaryVideo');
    }
}

function removeBlurFromSecondaryVideo() {
    if (secondaryVideo.poster) {
        secondaryVideo.poster = null; // Remove poster
    }
    if (localStream) {
        secondaryVideo.srcObject = localStream; // Restore live stream (do not call load() - breaks MediaStream on iOS)
        secondaryVideo.play().catch(function() {});
        console.log('Removed blur from secondaryVideo');
    }
}