// ============================================
// UPDATE THIS FILE: FcmNotificationsSender.java
// ============================================

// Add this import at the top
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

// ... existing code ...

public void SendNotifications() {
    System.out.println("📤 [FCM] Starting SendNotifications()");
    System.out.println("📤 [FCM] Device Type: " + device_type);
    System.out.println("📤 [FCM] Notification Type: " + notificationTypeKey);
    
    // Check if this is a CALL notification for iOS
    boolean isVoiceCall = "VOICE_CALL".equals(notificationTypeKey);
    boolean isVideoCall = "VIDEO_CALL".equals(notificationTypeKey);
    boolean isIOSDevice = !"1".equals(device_type); // iOS != "1"
    
    if ((isVoiceCall || isVideoCall) && isIOSDevice) {
        System.out.println("📞📞📞 [VOIP] ========================================");
        System.out.println("📞 [VOIP] Detected CALL notification for iOS!");
        System.out.println("📞 [VOIP] Call Type: " + (isVoiceCall ? "VOICE" : "VIDEO"));
        System.out.println("📞 [VOIP] Switching to VoIP Push for instant CallKit!");
        System.out.println("📞 [VOIP] ========================================");
        
        // 🆕 GET VOIP TOKEN FROM DATABASE (not hardcoded!)
        String voipToken = getVoIPTokenFromDatabase(to);
        
        if (voipToken == null || voipToken.isEmpty()) {
            System.err.println("❌ [VOIP] No VoIP token found for user: " + to);
            System.err.println("❌ [VOIP] User needs to login from iOS app first!");
            System.err.println("❌ [VOIP] Cannot send VoIP push without token.");
            return;
        }
        
        System.out.println("✅ [VOIP] Got VoIP token from database: " + voipToken.substring(0, 20) + "...");
        
        // Validate token format (must be 64 hex characters)
        if (!voipToken.matches("[0-9a-fA-F]{64}")) {
            System.err.println("❌ [VOIP] Invalid VoIP token format!");
            System.err.println("❌ [VOIP] Token: " + voipToken);
            System.err.println("❌ [VOIP] Expected: 64 hexadecimal characters");
            return;
        }
        
        System.out.println("✅ [VOIP] VoIP token validated - correct format");
        
        // Send VoIP push to APNs
        sendVoIPPushToAPNs(
            voipToken,
            name,           // caller name
            roomId,         // room ID
            to,             // receiver ID
            photo,          // caller photo
            mobile_no,      // caller phone
            isVoiceCall ? "Incoming voice call" : "Incoming video call"
        );
        
        System.out.println("✅ [VOIP] VoIP Push sent - iOS will show instant CallKit!");
        System.out.println("✅ [VOIP] Skipping FCM notification for calls");
        return;  // Don't send FCM for calls
    }
    
    // For non-call notifications OR Android devices, continue with FCM...
    // ... your existing FCM code ...
}

// 🆕 ADD THIS NEW METHOD
/**
 * Get VoIP token from database for a specific user
 * @param userId The user ID (uid) to fetch token for
 * @return VoIP token string, or null if not found
 */
private String getVoIPTokenFromDatabase(String userId) {
    Connection conn = null;
    PreparedStatement stmt = null;
    ResultSet rs = null;
    
    try {
        System.out.println("📊 [VOIP] Fetching VoIP token from database for user: " + userId);
        
        // Get database connection
        conn = getConnection(); // Your existing DB connection method
        
        // Query to get VoIP token
        String query = "SELECT voip_token, device_type FROM user_details WHERE uid = ?";
        stmt = conn.prepareStatement(query);
        stmt.setString(1, userId);
        
        rs = stmt.executeQuery();
        
        if (rs.next()) {
            String token = rs.getString("voip_token");
            String deviceType = rs.getString("device_type");
            
            System.out.println("📊 [VOIP] User found in database:");
            System.out.println("📊 [VOIP]   - UID: " + userId);
            System.out.println("📊 [VOIP]   - Device Type: " + deviceType);
            System.out.println("📊 [VOIP]   - VoIP Token: " + (token != null ? token.substring(0, 20) + "..." : "NULL"));
            
            // Check if token exists
            if (token == null || token.isEmpty()) {
                System.err.println("⚠️ [VOIP] VoIP token is empty for user: " + userId);
                return null;
            }
            
            return token;
        } else {
            System.err.println("❌ [VOIP] User not found in database: " + userId);
            return null;
        }
        
    } catch (Exception e) {
        System.err.println("❌ [VOIP] Database error while fetching VoIP token:");
        System.err.println("❌ [VOIP] Error: " + e.getMessage());
        e.printStackTrace();
        return null;
        
    } finally {
        // Clean up database resources
        try {
            if (rs != null) rs.close();
            if (stmt != null) stmt.close();
            if (conn != null) conn.close();
        } catch (Exception e) {
            System.err.println("❌ [VOIP] Error closing database connection: " + e.getMessage());
        }
    }
}

// Keep your existing sendVoIPPushToAPNs() method...
// ... rest of your code ...
