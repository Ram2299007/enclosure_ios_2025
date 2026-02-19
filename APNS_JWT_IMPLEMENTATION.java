// APNs JWT Token Implementation for Android Backend
// 
// Your APNs Key ID: 838GP97CYN
// 
// ⚠️ INSTRUCTIONS:
// 1. Copy your Team ID from Apple Developer Portal → Account → Membership
// 2. Open your AuthKey_838GP97CYN.p8 file and copy the private key content
// 3. Replace the placeholders below
// 4. Copy this entire implementation into FcmNotificationsSender.java
//    to replace the createAPNsJWT() method

package com.enclosure.Utils;

import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Base64;
import org.json.JSONObject;

public class APNsJWTHelper {
    
    // ✅ Your actual Key ID
    private static final String APNS_KEY_ID = "838GP97CYN";
    
    // ✅ Your Team ID
    private static final String APNS_TEAM_ID = "XR82K974UJ";
    
    // ✅ Your private key from AuthKey_838GP97CYN.p8 file
    private static final String APNS_PRIVATE_KEY = 
        "-----BEGIN PRIVATE KEY-----\n" +
        "MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQglV2GsFLF1OrMz6Jx\n" +
        "i4dF04TInoAVXvpkyYeub/EYB+GgCgYIKoZIzj0DAQehRANCAATul9xtMykbvPvm\n" +
        "WD1jSDfoH82QVsoiO1pQqtcfyWfrvUOUSCieWt+BOVLDDsLFLL1VTz5u3ZQ9oHbP\n" +
        "52p0sePJ\n" +
        "-----END PRIVATE KEY-----";
    
    /**
     * Create JWT token for APNs authentication
     * @return JWT token string, or null if error
     */
    public static String createAPNsJWT() {
        System.out.println("🔑 [APNs JWT] Creating JWT token...");
        System.out.println("🔑 [APNs JWT] Key ID: " + APNS_KEY_ID);
        System.out.println("🔑 [APNs JWT] Team ID: " + APNS_TEAM_ID);
        
        // Validate configuration
        if ("YOUR_TEAM_ID_HERE".equals(APNS_TEAM_ID)) {
            System.err.println("❌ [APNs JWT] Team ID not configured!");
            System.err.println("❌ [APNs JWT] Go to Apple Developer → Account → Membership");
            System.err.println("❌ [APNs JWT] Copy your Team ID and replace APNS_TEAM_ID");
            return null;
        }
        
        if (APNS_PRIVATE_KEY.contains("PASTE_YOUR_PRIVATE_KEY")) {
            System.err.println("❌ [APNs JWT] Private key not configured!");
            System.err.println("❌ [APNs JWT] Open AuthKey_838GP97CYN.p8 file");
            System.err.println("❌ [APNs JWT] Copy the entire content and replace APNS_PRIVATE_KEY");
            return null;
        }
        
        try {
            long now = System.currentTimeMillis() / 1000;
            
            // JWT Header
            JSONObject header = new JSONObject();
            header.put("alg", "ES256");
            header.put("kid", APNS_KEY_ID);
            
            // JWT Claims
            JSONObject claims = new JSONObject();
            claims.put("iss", APNS_TEAM_ID);
            claims.put("iat", now);
            
            // Encode header and claims
            String encodedHeader = base64UrlEncode(header.toString().getBytes("UTF-8"));
            String encodedClaims = base64UrlEncode(claims.toString().getBytes("UTF-8"));
            
            String unsignedToken = encodedHeader + "." + encodedClaims;
            
            // Sign with ES256
            byte[] signature = signWithES256(unsignedToken, APNS_PRIVATE_KEY);
            if (signature == null) {
                System.err.println("❌ [APNs JWT] Failed to sign token");
                return null;
            }
            
            String encodedSignature = base64UrlEncode(signature);
            
            String jwt = unsignedToken + "." + encodedSignature;
            
            System.out.println("✅ [APNs JWT] JWT token created successfully!");
            System.out.println("🔑 [APNs JWT] Token: " + jwt.substring(0, Math.min(50, jwt.length())) + "...");
            System.out.println("🔑 [APNs JWT] Token length: " + jwt.length() + " characters");
            
            return jwt;
            
        } catch (Exception e) {
            System.err.println("❌ [APNs JWT] Error creating JWT: " + e.getMessage());
            e.printStackTrace();
            return null;
        }
    }
    
    /**
     * Sign data with ES256 (ECDSA using P-256 and SHA-256)
     */
    private static byte[] signWithES256(String data, String privateKeyPEM) throws Exception {
        // Remove header/footer and decode
        String cleanKey = privateKeyPEM
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replaceAll("\\s", "");
        
        byte[] keyBytes = Base64.getDecoder().decode(cleanKey);
        
        // Create private key
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(keyBytes);
        KeyFactory keyFactory = KeyFactory.getInstance("EC");
        PrivateKey privateKey = keyFactory.generatePrivate(keySpec);
        
        // Sign with SHA256withECDSA
        Signature signature = Signature.getInstance("SHA256withECDSA");
        signature.initSign(privateKey);
        signature.update(data.getBytes("UTF-8"));
        
        return signature.sign();
    }
    
    /**
     * Base64 URL encode (without padding)
     */
    private static String base64UrlEncode(byte[] data) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(data);
    }
}

/*
 
 HOW TO USE THIS CODE IN FcmNotificationsSender.java:
 
 1. Replace APNS_TEAM_ID with your Team ID from Apple Developer Portal
 
 2. Replace APNS_PRIVATE_KEY with content from AuthKey_838GP97CYN.p8 file:
    - Open the .p8 file in a text editor
    - Copy everything (including BEGIN/END lines)
    - Paste it in the APNS_PRIVATE_KEY string above
    - Make sure to use "\n" for line breaks!
 
 3. In FcmNotificationsSender.java, replace the createAPNsJWT() method with:
 
    private String createAPNsJWT() {
        return APNsJWTHelper.createAPNsJWT();
    }
 
    Or copy the entire implementation directly into the class.
 
 4. Test by running the app and checking logs:
    ✅ [APNs JWT] JWT token created successfully!
 
 5. Send a test call and check if VoIP push works!
 
 */
