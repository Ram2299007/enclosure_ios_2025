//
//  MessageUploadService.swift
//  Enclosure
//
//  Created for message upload service matching Android MessageUploadService.java
//

import Foundation
import FirebaseDatabase
import FirebaseStorage
import Alamofire
import Security
import CommonCrypto

class MessageUploadService {
    static let shared = MessageUploadService()
    
    private let CREATE_INDIVIDUAL_CHATTING = Constant.baseURL + "create_individual_chatting"
    private let storageReference = Storage.storage().reference().child(Constant.CHAT)
    
    private init() {}
    
    // MARK: - Upload Message (matching Android uploadToServer)
    func uploadMessage(
        model: ChatMessage,
        filePath: String? = nil,
        userFTokenKey: String,
        deviceType: String = "2", // iOS device type
        completion: @escaping (Bool, String?) -> Void
    ) {
        print("📤 MessageUploadService: Starting upload for modelId=\(model.id)")
        
        // Check if selectionBunch has URLs (indicating pre-uploaded files)
        let selectionBunchPreUploaded = model.selectionBunch != nil && !(model.selectionBunch?.isEmpty ?? true)
        
        if selectionBunchPreUploaded {
            // Check if any selectionBunch item has a URL
            var hasUrls = false
            for bunch in model.selectionBunch ?? [] {
                if !bunch.imgUrl.isEmpty {
                    hasUrls = true
                    print("📤 Found URL in selectionBunch: \(bunch.imgUrl)")
                    break
                }
            }
        }
        
        // Build multipart form data (matching Android MultipartBody.Builder)
        AF.upload(
            multipartFormData: { multipartFormData in
                // Required fields (matching Android builder.addFormDataPart)
                multipartFormData.append(Data(model.uid.utf8), withName: "uid")
                multipartFormData.append(Data(model.receiverId.utf8), withName: "friend_id")
                multipartFormData.append(Data(model.message.utf8), withName: "message")
                multipartFormData.append(Data((model.userName ?? "").utf8), withName: "user_name")
                multipartFormData.append(Data("1".utf8), withName: "notification")
                multipartFormData.append(Data(model.dataType.utf8), withName: "dataType")
                multipartFormData.append(Data(model.id.utf8), withName: "model_id")
                multipartFormData.append(Data(model.time.utf8), withName: "sent_time")
                multipartFormData.append(Data((model.fileExtension ?? "").utf8), withName: "extension")
                multipartFormData.append(Data((model.name ?? "").utf8), withName: "name")
                multipartFormData.append(Data((model.phone ?? "").utf8), withName: "phone")
                multipartFormData.append(Data((model.micPhoto ?? "").utf8), withName: "micPhoto")
                multipartFormData.append(Data((model.miceTiming ?? "").utf8), withName: "miceTiming")
                multipartFormData.append(Data(userFTokenKey.utf8), withName: "fTokenKey")
                
                // Handle upload_docs (matching Android logic)
                if model.dataType == Constant.Text || model.dataType == Constant.contact {
                    multipartFormData.append(Data("".utf8), withName: "upload_docs")
                } else if !model.document.isEmpty {
                    // File exists in Firebase Storage, send the URL
                    print("📤 File exists, sending Firebase URL for upload_docs: \(model.document)")
                    multipartFormData.append(Data(model.document.utf8), withName: "upload_docs")
                } else if let filePath = filePath, !filePath.isEmpty, !selectionBunchPreUploaded {
                    // File does not exist, upload the local file
                    let fileURL = URL(fileURLWithPath: filePath)
                    if FileManager.default.fileExists(atPath: filePath) {
                        let fileSize = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64) ?? 0
                        if fileSize <= 200 * 1024 * 1024 { // 200MB limit
                            // Get mime type inline (avoiding closure capture issue)
                            let fileExtension = (filePath as NSString).pathExtension.lowercased()
                            let mimeType: String?
                            switch fileExtension {
                            case "jpg", "jpeg":
                                mimeType = "image/jpeg"
                            case "png":
                                mimeType = "image/png"
                            case "mp4":
                                mimeType = "video/mp4"
                            case "pdf":
                                mimeType = "application/pdf"
                            case "mp3":
                                mimeType = "audio/mpeg"
                            default:
                                mimeType = nil
                            }
                            
                            multipartFormData.append(
                                fileURL,
                                withName: "upload_docs",
                                fileName: fileURL.lastPathComponent,
                                mimeType: mimeType ?? "application/octet-stream"
                            )
                            print("📤 Uploading local file for upload_docs: \(filePath)")
                        } else {
                            print("❌ File exceeds 200MB: \(filePath)")
                            multipartFormData.append(Data("".utf8), withName: "upload_docs")
                        }
                    } else {
                        print("❌ File does not exist: \(filePath)")
                        multipartFormData.append(Data("".utf8), withName: "upload_docs")
                    }
                } else {
                    print("⚠️ No file to upload and no Firebase URL available")
                    multipartFormData.append(Data("".utf8), withName: "upload_docs")
                }
            },
            to: CREATE_INDIVIDUAL_CHATTING,
            method: .post
        ).responseJSON { response in
            switch response.result {
            case .success(let value):
                print("📩 Server response: \(value)")
                
                guard let json = value as? [String: Any] else {
                    print("❌ Invalid JSON response")
                    completion(false, "Invalid response format")
                    return
                }
                
                // Handle error_code as either Int or String (matching Android)
                let errorCode: Int
                if let errorCodeInt = json["error_code"] as? Int {
                    errorCode = errorCodeInt
                } else if let errorCodeString = json["error_code"] as? String,
                          let errorCodeInt = Int(errorCodeString) {
                    errorCode = errorCodeInt
                } else {
                    print("❌ Invalid error_code in response")
                    completion(false, "Invalid response format")
                    return
                }
                
                if errorCode == 200 {
                    // Success - update Firebase Realtime Database
                    if let data = json["data"] as? [String: Any] {
                        self.updateFirebaseDatabase(model: model) { success in
                            if success {
                                // Send push notification if needed
                                if !userFTokenKey.isEmpty {
                                    self.sendPushNotificationIfNeeded(
                                        model: model,
                                        userFTokenKey: userFTokenKey,
                                        deviceType: deviceType
                                    )
                                }
                                completion(true, nil)
                            } else {
                                completion(false, "Firebase update failed")
                            }
                        }
                    } else {
                        completion(true, nil) // API success but no data
                    }
                } else if errorCode == 205 {
                    let errorMessage = json["message"] as? String ?? "Unknown error"
                    print("❌ Server error 205: \(errorMessage)")
                    completion(false, errorMessage)
                } else {
                    let errorMessage = json["message"] as? String ?? "Unknown error"
                    print("❌ Server error: \(errorMessage)")
                    Constant.showToast(message: errorMessage)
                    completion(false, errorMessage)
                }
                
            case .failure(let error):
                print("❌ Network error: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            }
        }
    }
    
    // MARK: - Update Firebase Realtime Database (matching Android database.updateChildren)
    private func updateFirebaseDatabase(model: ChatMessage, completion: @escaping (Bool) -> Void) {
        let database = Database.database().reference()
        
        // Create senderRoom and receiverRoom (matching Android)
        let senderRoom = model.uid + model.receiverId
        let receiverRoom = model.receiverId + model.uid
        
        print("🔥 FirebaseStructure: SenderRoom=\(senderRoom), ReceiverRoom=\(receiverRoom)")
        print("🔥 FirebaseStructure: ModelID=\(model.id), UID=\(model.uid), ReceiverUID=\(model.receiverId)")
        
        // Convert model to dictionary (matching Android model.toMap())
        var senderMap = modelToDictionary(model: model)
        senderMap["timestamp"] = ServerValue.timestamp()
        
        // Update selectionBunch if available
        if let selectionBunch = model.selectionBunch, !selectionBunch.isEmpty {
            var selectionBunchArray: [[String: Any]] = []
            for bunch in selectionBunch {
                selectionBunchArray.append([
                    "imgUrl": bunch.imgUrl,
                    "fileName": bunch.fileName
                ])
            }
            senderMap["selectionBunch"] = selectionBunchArray
            print("🔥 Updated senderMap with selectionBunch: \(selectionBunchArray.count) items")
        }
        
        var receiverMap = modelToDictionary(model: model)
        receiverMap["timestamp"] = ServerValue.timestamp()
        
        // Update selectionBunch for receiver
        if let selectionBunch = model.selectionBunch, !selectionBunch.isEmpty {
            var selectionBunchArray: [[String: Any]] = []
            for bunch in selectionBunch {
                selectionBunchArray.append([
                    "imgUrl": bunch.imgUrl,
                    "fileName": bunch.fileName
                ])
            }
            receiverMap["selectionBunch"] = selectionBunchArray
            print("🔥 Updated receiverMap with selectionBunch: \(selectionBunchArray.count) items")
        }
        
        // Update Firebase (matching Android database.updateChildren)
        // Handle case where senderRoom and receiverRoom might be the same
        var updates: [String: Any] = [:]
        
        let senderPath = "\(Constant.CHAT)/\(senderRoom)/\(model.id)"
        let receiverPath = "\(Constant.CHAT)/\(receiverRoom)/\(model.id)"
        
        updates[senderPath] = senderMap
        
        // Only add receiver path if it's different from sender path
        if senderPath != receiverPath {
            updates[receiverPath] = receiverMap
        } else {
            // If same room, just use senderMap (user sending to themselves)
            print("⚠️ Sender and receiver are the same, using single path")
        }
        
        database.updateChildValues(updates) { error, _ in
            if let error = error {
                print("❌ Firebase sync failed: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Firebase sync successful")
                
                // Update chattingSocket (matching Android)
                let pushKey = database.child(Constant.chattingSocket).child(model.receiverId).childByAutoId().key ?? ""
                database.child(Constant.chattingSocket).child(model.receiverId).setValue(pushKey) { error, _ in
                    if let error = error {
                        print("❌ Push key sync failed: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("✅ Push key sync successful")
                        completion(true)
                    }
                }
            }
        }
    }
    
    // MARK: - Convert ChatMessage to Dictionary (matching Android model.toMap())
    private func modelToDictionary(model: ChatMessage) -> [String: Any] {
        var map: [String: Any] = [:]
        
        map["uid"] = model.uid
        map["message"] = model.message
        map["time"] = model.time
        map["document"] = model.document
        map["dataType"] = model.dataType
        map["extension"] = model.fileExtension ?? ""
        map["name"] = model.name ?? ""
        map["phone"] = model.phone ?? ""
        map["micPhoto"] = model.micPhoto ?? ""
        map["miceTiming"] = model.miceTiming ?? ""
        map["userName"] = model.userName ?? ""
        map["replytextData"] = model.replytextData ?? ""
        map["replyKey"] = model.replyKey ?? ""
        map["replyType"] = model.replyType ?? ""
        map["replyOldData"] = model.replyOldData ?? ""
        map["replyCrtPostion"] = model.replyCrtPostion ?? ""
        map["modelId"] = model.id
        map["receiverUid"] = model.receiverId
        map["forwaredKey"] = model.forwaredKey ?? ""
        map["groupName"] = model.groupName ?? ""
        map["docSize"] = model.docSize ?? ""
        map["fileName"] = model.fileName ?? ""
        map["thumbnail"] = model.thumbnail ?? ""
        map["fileNameThumbnail"] = model.fileNameThumbnail ?? ""
        map["caption"] = model.caption ?? ""
        map["notification"] = model.notification
        map["currentDate"] = model.currentDate ?? ""
        map["emojiCount"] = model.emojiCount ?? ""
        map["imageWidth"] = model.imageWidth ?? ""
        map["imageHeight"] = model.imageHeight ?? ""
        map["aspectRatio"] = model.aspectRatio ?? ""
        map["selectionCount"] = model.selectionCount ?? ""
        map["receiverLoader"] = model.receiverLoader
        
        // Convert emojiModel array
        if let emojiModels = model.emojiModel {
            var emojiArray: [[String: String]] = []
            for emoji in emojiModels {
                emojiArray.append([
                    "name": emoji.name,
                    "emoji": emoji.emoji
                ])
            }
            map["emojiModel"] = emojiArray
        }
        
        // Convert selectionBunch array
        if let selectionBunch = model.selectionBunch {
            var selectionBunchArray: [[String: String]] = []
            for bunch in selectionBunch {
                selectionBunchArray.append([
                    "imgUrl": bunch.imgUrl,
                    "fileName": bunch.fileName
                ])
            }
            map["selectionBunch"] = selectionBunchArray
        }
        
        return map
    }
    
    // MARK: - Send Push Notification (matching Android sendPushNotification)
    private func sendPushNotificationIfNeeded(
        model: ChatMessage,
        userFTokenKey: String,
        deviceType: String
    ) {
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        
        // Only send if receiver is not the current user
        if model.receiverId != uid {
            let messageBody: String
            switch model.dataType {
            case Constant.Text:
                messageBody = model.message
            case Constant.img:
                messageBody = "You have a new Image"
            case Constant.contact:
                messageBody = "You have a new Contact"
            case Constant.voiceAudio:
                messageBody = "You have a new Audio"
            case Constant.video:
                messageBody = "You have a new Video"
            default:
                messageBody = "You have a new File"
            }
            
            // Get sender info
            let senderId = Constant.SenderIdMy
            let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
            let profile = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
            let myFcmToken = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
            
            // Call notification API (matching Android Webservice.end_notification_api)
            sendNotificationAPI(
                userFTokenKey: userFTokenKey,
                userName: model.userName ?? "",
                message: messageBody,
                senderId: senderId,
                userName1: userName,
                profile: profile,
                sentTime: model.time,
                deviceType: deviceType,
                model: model,
                myFcmToken: myFcmToken
            )
        }
    }
    
    // MARK: - Send Notification API (matching Android end_notification_api)
    private func sendNotificationAPI(
        userFTokenKey: String,
        userName: String,
        message: String,
        senderId: String,
        userName1: String,
        profile: String,
        sentTime: String,
        deviceType: String,
        model: ChatMessage,
        myFcmToken: String
    ) {
        // Truncate message to 100 words (matching Android truncateToWords)
        let truncatedMessage = truncateToWords(message, maxWords: 100)
        
        print("📲 Preparing notification for modelId: \(model.id), uid: \(model.uid), receiverUid: \(model.receiverId)")
        
        // Get access token (matching Android Accesstoken.getAccessToke())
        // For now, we'll get it from a helper - you may need to implement GoogleCredentials in iOS
        getAccessToken { [weak self] accessToken in
            guard let self = self else { return }
            
            // Use access token if available, otherwise use placeholder
            // Note: For production, implement proper OAuth2 JWT signing with RSA private key
            // You may need to add SwiftJWT or similar library, or use a backend endpoint
            let finalAccessToken = accessToken ?? "NA"
            
            if accessToken == nil || accessToken!.isEmpty {
                print("⚠️ Access token not available for modelId: \(model.id) - using placeholder")
                print("⚠️ Notification may fail - implement proper OAuth2 token retrieval")
            }
            
            // Build JSON request (matching Android JSONObject)
            var requestJson: [String: Any] = [:]
            requestJson["deviceToken"] = self.safeString(userFTokenKey)
            requestJson["myFcmOwn"] = self.safeString(myFcmToken)
            requestJson["accessToken"] = self.safeString(finalAccessToken)
            requestJson["title"] = self.safeString(userName)
            requestJson["body"] = self.safeString(truncatedMessage)
            requestJson["receiverKey"] = self.safeString(senderId)
            requestJson["user_name"] = self.safeString(userName1)
            requestJson["photo"] = self.safeString(profile)
            requestJson["currentDateTimeString"] = self.safeString(sentTime)
            requestJson["deviceType"] = self.safeString(deviceType)
            requestJson["bodyKey"] = Constant.chatting
            requestJson["click_action"] = "OPEN_ACTIVITY_1"
            requestJson["icon"] = "notification_icon"
            requestJson["modelId"] = self.safeString(model.id)
            requestJson["receiverUid"] = self.safeString(model.receiverId)
            requestJson["forwardedKey"] = self.safeString(model.forwaredKey ?? "")
            requestJson["dataType"] = self.safeString(model.dataType)
            requestJson["selectionCount"] = self.safeString(model.selectionCount ?? "")
            
            print("📲 Notification request JSON for modelId: \(model.id): \(requestJson)")
            
            // Send POST request (matching Android OkHttp POST)
            let endpoint = Constant.baseURL + "EmojiController/send_notification_api"
            
            guard let url = URL(string: endpoint) else {
                print("❌ Invalid notification URL: \(endpoint)")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestJson)
            } catch {
                print("❌ Failed to serialize notification JSON: \(error.localizedDescription)")
                return
            }
            
            print("📲 Sending notification to URL: \(endpoint) for modelId: \(model.id)")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Notification failed for modelId: \(model.id): \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    let responseBody = data != nil ? String(data: data!, encoding: .utf8) ?? "" : ""
                    print("📲 Notification response for modelId: \(model.id), Status: \(statusCode), Body: \(responseBody)")
                    
                    if !(200...299).contains(statusCode) {
                        print("❌ Notification HTTP error \(statusCode): \(responseBody)")
                    }
                }
            }.resume()
        }
    }
    
    // MARK: - Get Access Token (matching Android Accesstoken.getAccessToke())
    private func getAccessToken(completion: @escaping (String?) -> Void) {
        // Option 1: Try backend endpoint first (if available)
        // Uncomment and set the endpoint if you have a backend that provides the token
        // getAccessTokenFromBackend { token in
        //     if let token = token {
        //         completion(token)
        //     } else {
        //         // Fallback to local generation
        //         self.generateAccessTokenLocally(completion: completion)
        //     }
        // }
        // return
        
        // Option 2: Generate locally (current implementation)
        generateAccessTokenLocally(completion: completion)
    }
    
    // MARK: - Generate Access Token Locally
    private func generateAccessTokenLocally(completion: @escaping (String?) -> Void) {
        // SECURITY: Service account credentials should NOT be hardcoded in source code
        // Get from secure storage (UserDefaults for development, Keychain for production)
        // Or use backend endpoint (recommended)
        
        guard let serviceAccountJSON = UserDefaults.standard.string(forKey: "FirebaseServiceAccountJSON"),
              !serviceAccountJSON.isEmpty else {
            print("⚠️ Service account JSON not found in secure storage")
            print("⚠️ Please add it via UserDefaults or implement backend endpoint")
            print("⚠️ For development: UserDefaults.standard.set(serviceAccountJSON, forKey: \"FirebaseServiceAccountJSON\")")
            completion(nil)
            return
        }
        
        // Parse service account JSON
        guard let jsonData = serviceAccountJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let privateKey = json["private_key"] as? String,
              let clientEmail = json["client_email"] as? String,
              let tokenUri = json["token_uri"] as? String else {
            print("❌ Failed to parse service account JSON")
            completion(nil)
            return
        }
        
        // Get access token using OAuth2 JWT flow (matching Android GoogleCredentials)
        getOAuth2AccessToken(
            privateKey: privateKey,
            clientEmail: clientEmail,
            tokenUri: tokenUri,
            scope: "https://www.googleapis.com/auth/firebase.messaging",
            completion: completion
        )
    }
    
    // MARK: - OAuth2 Access Token Retrieval
    private func getOAuth2AccessToken(
        privateKey: String,
        clientEmail: String,
        tokenUri: String,
        scope: String,
        completion: @escaping (String?) -> Void
    ) {
        // Try to get cached token first
        if let cachedToken = getCachedAccessToken(), !isTokenExpired(cachedToken) {
            print("✅ Using cached access token")
            completion(cachedToken.token)
            return
        }
        
        // Create JWT for service account authentication (matching Android GoogleCredentials)
        let now = Int(Date().timeIntervalSince1970)
        let expiry = now + 3600 // 1 hour
        
        // Create JWT claim set
        let header: [String: Any] = [
            "alg": "RS256",
            "typ": "JWT"
        ]
        
        let claim: [String: Any] = [
            "iss": clientEmail,
            "scope": scope,
            "aud": tokenUri,
            "exp": expiry,
            "iat": now
        ]
        
        // Encode JWT header and payload
        guard let headerData = try? JSONSerialization.data(withJSONObject: header),
              let claimData = try? JSONSerialization.data(withJSONObject: claim),
              let headerBase64 = base64URLEncode(headerData),
              let claimBase64 = base64URLEncode(claimData) else {
            print("❌ Failed to encode JWT header/claim")
            completion(nil)
            return
        }
        
        let unsignedJWT = "\(headerBase64).\(claimBase64)"
        
        // Sign JWT with RSA private key
        signJWT(unsignedJWT: unsignedJWT, privateKey: privateKey) { [weak self] signature in
            guard let self = self, let signature = signature else {
                print("❌ Failed to sign JWT")
                completion(nil)
                return
            }
            
            let signedJWT = "\(unsignedJWT).\(signature)"
            print("✅ JWT created successfully")
            
            // Exchange JWT for access token
            self.exchangeJWTForAccessToken(jwt: signedJWT, tokenUri: tokenUri) { accessToken, expiresIn in
                if let accessToken = accessToken, let expiresIn = expiresIn {
                    // Cache the token
                    self.cacheAccessToken(accessToken, expiresIn: expiresIn)
                    print("✅ Access token obtained successfully")
                    completion(accessToken)
                } else {
                    print("❌ Failed to exchange JWT for access token")
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - JWT Signing with RSA
    private func signJWT(unsignedJWT: String, privateKey: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Parse PEM private key
            let cleanedKey = privateKey
                .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
                .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
                .replacingOccurrences(of: "\\n", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: " ", with: "")
            
            guard let keyData = Data(base64Encoded: cleanedKey) else {
                print("❌ Failed to decode private key")
                completion(nil)
                return
            }
            
            // Import PKCS#8 private key using SecKeyCreateWithData
            // Note: iOS SecKeyCreateWithData expects PKCS#1 format, but we have PKCS#8
            // We need to extract the RSA key from PKCS#8 structure
            let keyDict: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                kSecAttrKeySizeInBits as String: 2048
            ]
            
            var error: Unmanaged<CFError>?
            var secKey: SecKey?
            
            // Try direct import first (works for some PKCS#8 keys)
            secKey = SecKeyCreateWithData(keyData as CFData, keyDict as CFDictionary, &error)
            
            // If that fails, try extracting PKCS#1 from PKCS#8
            if secKey == nil {
                print("⚠️ Direct PKCS#8 import failed, trying PKCS#1 extraction...")
                if let pkcs1Data = self.extractPKCS1FromPKCS8(keyData) {
                    print("✅ Extracted PKCS#1 key, length: \(pkcs1Data.count) bytes")
                    secKey = SecKeyCreateWithData(pkcs1Data as CFData, keyDict as CFDictionary, &error)
                    if secKey == nil {
                        let errorDesc = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
                        print("❌ Failed to create SecKey from PKCS#1: \(errorDesc)")
                    }
                } else {
                    print("❌ Failed to extract PKCS#1 from PKCS#8")
                }
            }
            
            guard let secKey = secKey else {
                let errorDesc = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
                print("❌ Failed to create SecKey: \(errorDesc)")
                print("⚠️ Since Android works, consider:")
                print("   1. Creating a backend endpoint that provides the access token")
                print("   2. Using a JWT library like SwiftJWT")
                print("   3. Sharing the token generation logic between platforms")
                completion(nil)
                return
            }
            
            print("✅ SecKey created successfully")
            
            // Sign the JWT
            guard let messageData = unsignedJWT.data(using: .utf8) else {
                print("❌ Failed to convert JWT to data")
                completion(nil)
                return
            }
            
            var error2: Unmanaged<CFError>?
            guard let signature = SecKeyCreateSignature(
                secKey,
                .rsaSignatureMessagePKCS1v15SHA256,
                messageData as CFData,
                &error2
            ) as Data? else {
                print("❌ Failed to sign JWT: \(error2?.takeRetainedValue().localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            // Encode signature as base64 URL
            let signatureBase64 = self.base64URLEncode(signature)
            completion(signatureBase64)
        }
    }
    
    // MARK: - Exchange JWT for Access Token
    private func exchangeJWTForAccessToken(jwt: String, tokenUri: String, completion: @escaping (String?, Int?) -> Void) {
        guard let url = URL(string: tokenUri) else {
            print("❌ Invalid token URI: \(tokenUri)")
            completion(nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)"
        request.httpBody = bodyString.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Token exchange error: \(error.localizedDescription)")
                completion(nil, nil)
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                let responseBody = data != nil ? String(data: data!, encoding: .utf8) ?? "" : ""
                print("❌ Failed to parse token response: \(responseBody)")
                completion(nil, nil)
                return
            }
            
            let expiresIn = json["expires_in"] as? Int ?? 3600
            completion(accessToken, expiresIn)
        }.resume()
    }
    
    // MARK: - Extract PKCS#1 from PKCS#8 (Improved ASN.1 parsing)
    private func extractPKCS1FromPKCS8(_ pkcs8Data: Data) -> Data? {
        // PKCS#8 structure: SEQUENCE { version INTEGER, algorithmIdentifier SEQUENCE, privateKey OCTET STRING }
        // The privateKey OCTET STRING contains the PKCS#1 key (RSAPrivateKey)
        
        var index = 0
        
        // Helper to read DER length
        func readDERLength() -> Int? {
            guard index < pkcs8Data.count else { return nil }
            if pkcs8Data[index] & 0x80 == 0 {
                // Short form
                let length = Int(pkcs8Data[index])
                index += 1
                return length
            } else {
                // Long form
                let lengthOfLength = Int(pkcs8Data[index] & 0x7F)
                guard lengthOfLength > 0 && lengthOfLength <= 4 else { return nil }
                index += 1
                var length = 0
                for _ in 0..<lengthOfLength {
                    guard index < pkcs8Data.count else { return nil }
                    length = (length << 8) | Int(pkcs8Data[index])
                    index += 1
                }
                return length
            }
        }
        
        // Skip outer SEQUENCE (0x30)
        guard index < pkcs8Data.count && pkcs8Data[index] == 0x30 else { return nil }
        index += 1
        
        // Skip SEQUENCE length
        guard let _ = readDERLength() else { return nil }
        
        // Skip version INTEGER (0x02)
        guard index < pkcs8Data.count && pkcs8Data[index] == 0x02 else { return nil }
        index += 1
        guard let versionLength = readDERLength() else { return nil }
        index += versionLength
        
        // Skip algorithmIdentifier SEQUENCE (0x30)
        guard index < pkcs8Data.count && pkcs8Data[index] == 0x30 else { return nil }
        index += 1
        guard let algLength = readDERLength() else { return nil }
        index += algLength
        
        // Read privateKey OCTET STRING (0x04)
        guard index < pkcs8Data.count && pkcs8Data[index] == 0x04 else { return nil }
        index += 1
        guard let keyLength = readDERLength() else { return nil }
        
        // Extract PKCS#1 key data
        guard index + keyLength <= pkcs8Data.count else { return nil }
        return pkcs8Data.subdata(in: index..<(index + keyLength))
    }
    
    // MARK: - Get Access Token from Backend (Recommended for Production)
    private func getAccessTokenFromBackend(completion: @escaping (String?) -> Void) {
        // TODO: Implement backend endpoint that provides the access token
        // This is the recommended approach to keep private keys secure
        // Example implementation:
        // let endpoint = Constant.baseURL + "get_firebase_access_token"
        // AF.request(endpoint, method: .post).responseJSON { response in
        //     if let json = response.value as? [String: Any],
        //        let token = json["access_token"] as? String {
        //         completion(token)
        //     } else {
        //         completion(nil)
        //     }
        // }
        completion(nil)
    }
    
    // MARK: - Base64 URL Encoding
    private func base64URLEncode(_ data: Data) -> String? {
        let base64 = data.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    // MARK: - Token Caching
    private struct CachedToken {
        let token: String
        let expiry: Date
    }
    
    private var cachedAccessToken: CachedToken?
    
    private func getCachedAccessToken() -> CachedToken? {
        return cachedAccessToken
    }
    
    private func isTokenExpired(_ cachedToken: CachedToken) -> Bool {
        return cachedToken.expiry < Date()
    }
    
    private func cacheAccessToken(_ token: String, expiresIn: Int) {
        let expiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        cachedAccessToken = CachedToken(token: token, expiry: expiry)
    }
    
    // MARK: - Helper: Truncate to Words (matching Android truncateToWords)
    private func truncateToWords(_ text: String, maxWords: Int) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count <= maxWords {
            return text
        }
        return words.prefix(maxWords).joined(separator: " ")
    }
    
    // MARK: - Helper: Safe String (matching Android safeString)
    private func safeString(_ value: String?) -> String {
        guard let value = value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "NA"
        }
        return value
    }
    
    // MARK: - Helper Methods
    private func getMimeType(filePath: String) -> String? {
        let fileExtension = (filePath as NSString).pathExtension.lowercased()
        switch fileExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "mp4":
            return "video/mp4"
        case "pdf":
            return "application/pdf"
        case "mp3":
            return "audio/mpeg"
        default:
            return nil
        }
    }
}

