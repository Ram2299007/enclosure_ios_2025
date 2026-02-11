// APNs JWT Token Implementation for Enclosure
// 
// Your APNs Key ID: 838GP97CYN
// 
// ⚠️ INSTRUCTIONS:
// 1. Copy your Team ID from Apple Developer Portal → Account → Membership
// 2. Open your AuthKey_838GP97CYN.p8 file and copy the private key content
// 3. Replace the placeholders below
// 4. Copy this entire implementation into MessageUploadService.swift
//    to replace the createAPNsJWT() method

import Foundation
import CommonCrypto
import Security

// MARK: - APNs Configuration
private let APNS_KEY_ID = "838GP97CYN"  // ✅ Your actual Key ID
private let APNS_TEAM_ID = "XR82K974UJ"  // ✅ Your Team ID

// ✅ Your private key from AuthKey_838GP97CYN.p8 file
private let APNS_PRIVATE_KEY = """
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQglV2GsFLF1OrMz6Jx
i4dF04TInoAVXvpkyYeub/EYB+GgCgYIKoZIzj0DAQehRANCAATul9xtMykbvPvm
WD1jSDfoH82QVsoiO1pQqtcfyWfrvUOUSCieWt+BOVLDDsLFLL1VTz5u3ZQ9oHbP
52p0sePJ
-----END PRIVATE KEY-----
"""

// MARK: - JWT Token Creation
func createAPNsJWT() -> String? {
    print("🔑 [APNs JWT] Creating JWT token...")
    print("🔑 [APNs JWT] Key ID: \(APNS_KEY_ID)")
    print("🔑 [APNs JWT] Team ID: \(APNS_TEAM_ID)")
    
    // Validate configuration
    if APNS_TEAM_ID == "YOUR_TEAM_ID_HERE" {
        print("❌ [APNs JWT] Team ID not configured!")
        print("❌ [APNs JWT] Go to Apple Developer → Account → Membership")
        print("❌ [APNs JWT] Copy your Team ID and replace APNS_TEAM_ID")
        return nil
    }
    
    if APNS_PRIVATE_KEY.contains("PASTE_YOUR_PRIVATE_KEY") {
        print("❌ [APNs JWT] Private key not configured!")
        print("❌ [APNs JWT] Open AuthKey_838GP97CYN.p8 file")
        print("❌ [APNs JWT] Copy the entire content and replace APNS_PRIVATE_KEY")
        return nil
    }
    
    let now = Int(Date().timeIntervalSince1970)
    
    // JWT Header
    let header: [String: Any] = [
        "alg": "ES256",
        "kid": APNS_KEY_ID
    ]
    
    // JWT Claims
    let claims: [String: Any] = [
        "iss": APNS_TEAM_ID,
        "iat": now
    ]
    
    guard let headerData = try? JSONSerialization.data(withJSONObject: header),
          let claimsData = try? JSONSerialization.data(withJSONObject: claims),
          let headerBase64 = base64URLEncode(headerData),
          let claimsBase64 = base64URLEncode(claimsData) else {
        print("❌ [APNs JWT] Failed to encode header/claims")
        return nil
    }
    
    let unsignedToken = "\(headerBase64).\(claimsBase64)"
    
    // Sign with ES256
    guard let signature = signWithES256(data: unsignedToken, privateKey: APNS_PRIVATE_KEY),
          let signatureBase64 = base64URLEncode(signature) else {
        print("❌ [APNs JWT] Failed to sign token")
        return nil
    }
    
    let jwt = "\(unsignedToken).\(signatureBase64)"
    
    print("✅ [APNs JWT] JWT token created successfully!")
    print("🔑 [APNs JWT] Token: \(jwt.prefix(50))...")
    print("🔑 [APNs JWT] Token length: \(jwt.count) characters")
    
    return jwt
}

// MARK: - Helper Functions

private func base64URLEncode(_ data: Data) -> String? {
    let base64 = data.base64EncodedString()
    return base64
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func signWithES256(data: String, privateKey: String) -> Data? {
    // Clean private key
    let cleanedKey = privateKey
        .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
        .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
        .replacingOccurrences(of: "\n", with: "")
        .replacingOccurrences(of: " ", with: "")
    
    guard let keyData = Data(base64Encoded: cleanedKey) else {
        print("❌ [APNs JWT] Failed to decode private key")
        return nil
    }
    
    // Create SecKey from PKCS#8 data
    let keyDict: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeEC,
        kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        kSecAttrKeySizeInBits as String: 256
    ]
    
    var error: Unmanaged<CFError>?
    guard let secKey = SecKeyCreateWithData(keyData as CFData, keyDict as CFDictionary, &error) else {
        if let error = error?.takeRetainedValue() {
            print("❌ [APNs JWT] SecKey error: \(error)")
        }
        return nil
    }
    
    // Sign data
    guard let messageData = data.data(using: .utf8) else {
        print("❌ [APNs JWT] Failed to convert data to UTF8")
        return nil
    }
    
    var signError: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(
        secKey,
        .ecdsaSignatureMessageX962SHA256,
        messageData as CFData,
        &signError
    ) as Data? else {
        if let error = signError?.takeRetainedValue() {
            print("❌ [APNs JWT] Signing error: \(error)")
        }
        return nil
    }
    
    return signature
}

// MARK: - Usage Instructions
/*
 
 HOW TO USE THIS CODE:
 
 1. Replace APNS_TEAM_ID with your Team ID from Apple Developer Portal
 
 2. Replace APNS_PRIVATE_KEY with content from AuthKey_838GP97CYN.p8 file:
    - Open the .p8 file in TextEdit or any text editor
    - Copy everything (including BEGIN/END lines)
    - Paste it in the APNS_PRIVATE_KEY string above
 
 3. Copy the entire createAPNsJWT() function and helper functions
    into MessageUploadService.swift to replace the existing placeholder
 
 4. Test by running the app and checking logs:
    ✅ [APNs JWT] JWT token created successfully!
 
 5. Send a test call and check if VoIP push works!
 
 */
