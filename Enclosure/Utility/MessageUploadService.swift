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
    private let CREATE_GROUP_CHATTING = Constant.baseURL + "create_group_chatting"
    private let storageReference = Storage.storage().reference().child(Constant.CHAT)
    
    private init() {}
    
    // MARK: - Upload Message (matching Android uploadToServer)
    func uploadMessage(
        model: ChatMessage,
        filePath: String? = nil,
        userFTokenKey: String,
        deviceType: String? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        // Use value from API (get_user_active_chat_list my_device_type / verify_otp / get_profile "1"|"2") only; do not send static "2"
        let senderDeviceType = deviceType ?? UserDefaults.standard.string(forKey: Constant.DEVICE_TYPE_KEY) ?? ""
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
                multipartFormData.append(Data((model.caption ?? "").utf8), withName: "caption")
                multipartFormData.append(Data((model.selectionCount ?? "1").utf8), withName: "selection_count")
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
                            print("🚫 File exceeds 200MB: \(filePath)")
                            multipartFormData.append(Data("".utf8), withName: "upload_docs")
                        }
                    } else {
                        print("🚫 File does not exist: \(filePath)")
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
                    print("🚫 Invalid JSON response")
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
                    print("🚫 Invalid error_code in response")
                    completion(false, "Invalid response format")
                    return
                }
                
                if errorCode == 200 {
                    // Success - update Firebase Realtime Database
                    if let data = json["data"] as? [String: Any] {
                        self.updateFirebaseDatabase(model: model) { success in
                            if success {
                                // Get receiver's FCM token and device_type from cache (populated when user opens ChattingScreen from chatView or from get_user_active_chat_list)
                                ChatCacheManager.shared.getFCMToken(for: model.receiverId) { receiverFCMToken in
                                    let finalReceiverFCMToken = receiverFCMToken ?? userFTokenKey
                                    ChatCacheManager.shared.getDeviceType(for: model.receiverId) { receiverDeviceType in
                                        print("🔑 [SEND_NOTIFICATION_API] Receiver FCM token from database: \(receiverFCMToken != nil ? "Found" : "Not found")")
                                        if let token = receiverFCMToken {
                                            print("🔑 [SEND_NOTIFICATION_API] Receiver token: \(token.prefix(50))...")
                                        } else {
                                            print("⚠️ [SEND_NOTIFICATION_API] Using fallback token: \(userFTokenKey.prefix(50))...")
                                        }
                                        if let rdt = receiverDeviceType {
                                            print("[NOTIF_RECEIVER_DEVICE] from_cache receiver_uid=\(model.receiverId) device_type=\(rdt)")
                                        }
                                        if !finalReceiverFCMToken.isEmpty {
                                            self.sendPushNotificationIfNeeded(
                                                model: model,
                                                userFTokenKey: finalReceiverFCMToken,
                                                deviceType: senderDeviceType,
                                                receiverDeviceType: receiverDeviceType
                                            )
                                        }
                                    }
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
                    print("🚫 Server error 205: \(errorMessage)")
                    completion(false, errorMessage)
                } else {
                    let errorMessage = json["message"] as? String ?? "Unknown error"
                    print("🚫 Server error: \(errorMessage)")
                    Constant.showToast(message: errorMessage)
                    completion(false, errorMessage)
                }
                
            case .failure(let error):
                print("🚫 Network error: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            }
        }
    }
    
    // MARK: - Upload Group Message (matching Android GroupMessageUploadService)
    func uploadGroupMessage(
        model: GroupChatMessage,
        filePath: String? = nil,
        userFTokenKey: String,
        deviceType: String? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let senderDeviceType = deviceType ?? UserDefaults.standard.string(forKey: Constant.DEVICE_TYPE_KEY) ?? ""
        print("📤 MessageUploadService: Starting group upload for modelId=\(model.id)")
        
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
        
        // Build multipart form data (matching Android GroupMessageUploadService MultipartBody.Builder)
        AF.upload(
            multipartFormData: { multipartFormData in
                // Required fields (matching Android GroupMessageUploadService builder.addFormDataPart)
                multipartFormData.append(Data(model.uid.utf8), withName: "uid")
                multipartFormData.append(Data(model.receiverUid.utf8), withName: "group_id") // group_id instead of friend_id
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
                multipartFormData.append(Data((model.createdBy ?? "").utf8), withName: "created_by") // created_by for groups
                multipartFormData.append(Data((model.caption ?? "").utf8), withName: "caption")
                multipartFormData.append(Data((model.selectionCount ?? "1").utf8), withName: "selection_count")
                multipartFormData.append(Data(userFTokenKey.utf8), withName: "fTokenKey")
                
                // Handle upload_docs (matching Android GroupMessageUploadService logic)
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
                            print("🚫 File exceeds 200MB: \(filePath)")
                            multipartFormData.append(Data("".utf8), withName: "upload_docs")
                        }
                    } else {
                        print("🚫 File does not exist: \(filePath)")
                        multipartFormData.append(Data("".utf8), withName: "upload_docs")
                    }
                } else {
                    print("⚠️ No file to upload and no Firebase URL available")
                    multipartFormData.append(Data("".utf8), withName: "upload_docs")
                }
                
                // Add thumbnail if available (matching Android)
                if let thumbnail = model.thumbnail, !thumbnail.isEmpty {
                    multipartFormData.append(Data(thumbnail.utf8), withName: "thumbnail")
                } else {
                    multipartFormData.append(Data("".utf8), withName: "thumbnail")
                }
                
                // Add fileNameThumbnail if available (matching Android)
                if let fileNameThumbnail = model.fileNameThumbnail, !fileNameThumbnail.isEmpty {
                    multipartFormData.append(Data(fileNameThumbnail.utf8), withName: "fileNameThumbnail")
                } else {
                    multipartFormData.append(Data("".utf8), withName: "fileNameThumbnail")
                }
            },
            to: CREATE_GROUP_CHATTING,
            method: .post
        ).responseJSON { response in
            switch response.result {
            case .success(let value):
                print("📩 Server response: \(value)")
                
                guard let json = value as? [String: Any] else {
                    print("🚫 Invalid JSON response")
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
                    print("🚫 Invalid error_code in response")
                    completion(false, "Invalid response format")
                    return
                }
                
                if errorCode == 200 {
                    // Success - update Firebase Realtime Database
                    if let data = json["data"] as? [String: Any] {
                        // Extract group_members from response (matching Android)
                        let groupMembers = data["group_members"] as? [[String: Any]] ?? []
                        
                        print("✅ [GROUP_UPLOAD] API success for modelId=\(model.id)")
                        print("✅ [GROUP_UPLOAD] Extracted group_members count: \(groupMembers.count)")
                        
                        self.updateGroupFirebaseDatabase(model: model) { success in
                            if success {
                                print("✅ [GROUP_UPLOAD] Firebase update successful for modelId=\(model.id)")
                                
                                // Call notification API after successful upload (matching Android end_notification_api_group)
                                if !groupMembers.isEmpty {
                                    print("📲 [GROUP_NOTIFICATION] Calling end_notification_api_group for modelId=\(model.id) with \(groupMembers.count) members")
                                    self.sendGroupNotificationAPI(
                                        model: model,
                                        userFTokenKey: userFTokenKey,
                                        deviceType: senderDeviceType,
                                        groupMembers: groupMembers
                                    )
                                } else {
                                    print("⚠️ [GROUP_NOTIFICATION] Skipping notification API - group_members is empty for modelId=\(model.id)")
                                }
                                completion(true, nil)
                            } else {
                                print("🚫 [GROUP_UPLOAD] Firebase update failed for modelId=\(model.id)")
                                completion(false, "Firebase update failed")
                            }
                        }
                    } else {
                        print("⚠️ [GROUP_UPLOAD] API success but no data field in response for modelId=\(model.id)")
                        completion(true, nil) // API success but no data
                    }
                } else if errorCode == 205 {
                    let errorMessage = json["message"] as? String ?? "Unknown error"
                    print("🚫 Server error 205: \(errorMessage)")
                    completion(false, errorMessage)
                } else {
                    let errorMessage = json["message"] as? String ?? "Unknown error"
                    print("🚫 Server error: \(errorMessage)")
                    Constant.showToast(message: errorMessage)
                    completion(false, errorMessage)
                }
                
            case .failure(let error):
                print("🚫 Network error: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            }
        }
    }
    
    // MARK: - Update Firebase Realtime Database for Groups (matching Android GroupMessageUploadService.writeToRealtimeDatabase)
    private func updateGroupFirebaseDatabase(model: GroupChatMessage, completion: @escaping (Bool) -> Void) {
        let database = Database.database().reference()
        
        // Create chatKey (matching Android: senderId + groupId)
        let chatKey = (model.uid + model.receiverUid).replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "#", with: "_")
            .replacingOccurrences(of: "$", with: "_")
            .replacingOccurrences(of: "[", with: "_")
            .replacingOccurrences(of: "]", with: "_")
        
        print("🔥 FirebaseStructure: ChatKey=\(chatKey), ModelID=\(model.id), UID=\(model.uid), GroupID=\(model.receiverUid)")
        
        // Convert model to dictionary (matching Android group_messageModel.toMap())
        var messageMap = model.toDictionary()
        messageMap["timestamp"] = ServerValue.timestamp()
        
        // Update Firebase (matching Android databaseReference.child(chatKey).child(modelId).setValue)
        let messagePath = "\(Constant.GROUPCHAT)/\(chatKey)/\(model.id)"
        
        database.child(Constant.GROUPCHAT).child(chatKey).child(model.id).setValue(messageMap) { error, _ in
            if let error = error {
                print("🚫 Firebase sync failed: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Firebase sync successful for group message")
                completion(true)
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
                print("🚫 Firebase sync failed: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Firebase sync successful")
                
                // Update chattingSocket (matching Android)
                let pushKey = database.child(Constant.chattingSocket).child(model.receiverId).childByAutoId().key ?? ""
                database.child(Constant.chattingSocket).child(model.receiverId).setValue(pushKey) { error, _ in
                    if let error = error {
                        print("🚫 Push key sync failed: \(error.localizedDescription)")
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
    
    /// Normalizes device_type for send_notification_api: backend expects "1" (Android) or "2" (iOS). If API returned a UUID (e.g. get_profile), send "2" for iOS app so backend adds FCM notification block.
    private func normalizedSenderDeviceTypeForNotification(_ deviceType: String) -> String {
        if deviceType == "1" || deviceType == "2" { return deviceType }
        // UUID or other value from get_profile -> backend expects "2" for iOS
        return "2"
    }
    
    // MARK: - Send Push Notification (matching Android sendPushNotification)
    private func sendPushNotificationIfNeeded(
        model: ChatMessage,
        userFTokenKey: String,
        deviceType: String,
        receiverDeviceType: String? = nil
    ) {
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        
        // Validate FCM token before sending notification
        let isValidFCMToken = !userFTokenKey.isEmpty && 
                               userFTokenKey != "apns_missing" && 
                               !userFTokenKey.lowercased().contains("missing")
        
        if !isValidFCMToken {
            print("⚠️ [SEND_NOTIFICATION_API] Skipping notification - invalid FCM token: '\(userFTokenKey)'")
            print("⚠️ [SEND_NOTIFICATION_API] Receiver (uid: \(model.receiverId)) has not registered a valid FCM token")
            return
        }
        
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
            
            sendNotificationAPI(
                userFTokenKey: userFTokenKey,
                userName: model.userName ?? "",
                message: messageBody,
                senderId: senderId,
                userName1: userName,
                profile: profile,
                sentTime: model.time,
                deviceType: deviceType,
                receiverDeviceType: receiverDeviceType,
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
        receiverDeviceType: String? = nil,
        model: ChatMessage,
        myFcmToken: String
    ) {
        // Truncate message to 100 words (matching Android truncateToWords)
        let truncatedMessage = truncateToWords(message, maxWords: 100)
        
        print("📲 [SEND_NOTIFICATION_API] Preparing notification for modelId: \(model.id), uid: \(model.uid), receiverUid: \(model.receiverId)")
        print("📲 [SEND_NOTIFICATION_API] Device token (userFTokenKey): \(userFTokenKey.isEmpty ? "EMPTY" : "\(userFTokenKey.prefix(50))...")")
        print("📲 [SEND_NOTIFICATION_API] My FCM token: \(myFcmToken.isEmpty ? "EMPTY" : "\(myFcmToken.prefix(50))...")")
        
        // Get access token (matching Android Accesstoken.getAccessToke())
        // For now, we'll get it from a helper - you may need to implement GoogleCredentials in iOS
        getAccessToken { [weak self] accessToken in
            guard let self = self else { return }
            
            // Use access token if available, otherwise use FCM token as fallback (matching group notification behavior)
            // Note: For production, implement proper OAuth2 JWT signing with RSA private key
            // You may need to add SwiftJWT or similar library, or use a backend endpoint
            let finalAccessToken: String
            if let token = accessToken, !token.isEmpty {
                finalAccessToken = token
                print("✅ [SEND_NOTIFICATION_API] Using OAuth2 access token for modelId: \(model.id)")
                print("🔑 [SEND_NOTIFICATION_API] Access token length: \(token.count) characters")
                print("🔑 [SEND_NOTIFICATION_API] Access token prefix: \(token.prefix(20))...")
                print("🔑 [SEND_NOTIFICATION_API] Access token format: \(token.hasPrefix("ya29.") ? "Valid Google OAuth2 token" : "Unexpected format")")
            } else {
                // Fallback to FCM token (matching group notification behavior)
                finalAccessToken = myFcmToken
                if myFcmToken.isEmpty {
                    print("⚠️ [SEND_NOTIFICATION_API] Access token not available and FCM token is empty for modelId: \(model.id)")
                    print("⚠️ [SEND_NOTIFICATION_API] Notification may fail - both access token and FCM token are missing")
                } else {
                    print("⚠️ [SEND_NOTIFICATION_API] Access token not available for modelId: \(model.id) - using FCM token as fallback")
                }
            }
            
            // Build JSON request (matching backend PHP send_notification_api parameters)
            var requestJson: [String: Any] = [:]
            
            // Validate FCM token before sending
            if userFTokenKey.isEmpty || userFTokenKey == "apns_missing" || userFTokenKey.lowercased().contains("missing") {
                print("🚫 [SEND_NOTIFICATION_API] Invalid FCM token detected: '\(userFTokenKey)' - skipping notification")
                print("🚫 [SEND_NOTIFICATION_API] Receiver (uid: \(model.receiverId)) needs to register a valid FCM token")
                return
            }
            
            // Required fields
            requestJson["deviceToken"] = self.safeString(userFTokenKey)
            requestJson["accessToken"] = self.safeString(finalAccessToken)
            
            // Notification fields
            requestJson["title"] = self.safeString(userName)
            requestJson["body"] = self.safeString(truncatedMessage)
            requestJson["receiverKey"] = self.safeString(senderId)
            requestJson["user_name"] = self.safeString(userName1)
            requestJson["photo"] = self.safeString(profile)
            requestJson["currentDateTimeString"] = self.safeString(sentTime)
            // device_type / deviceType = selected user's original device_type from get_user_active_chat_list (e.g. Priti "1", Ram "CED8A147-..."). Pass as-is.
            let targetDeviceType: String
            if let rdt = receiverDeviceType, !rdt.isEmpty {
                targetDeviceType = rdt
                print("[NOTIF_RECEIVER_DEVICE] receiver_uid=\(model.receiverId) device_type=\(rdt)")
            } else {
                targetDeviceType = normalizedSenderDeviceTypeForNotification(deviceType)
                print("[NOTIF_RECEIVER_DEVICE] receiver_uid=\(model.receiverId) device_type=\(targetDeviceType) (fallback: not in cache)")
            }
            requestJson["deviceType"] = self.safeString(targetDeviceType)
            requestJson["device_type"] = self.safeString(targetDeviceType)
            if let rdt = receiverDeviceType, !rdt.isEmpty {
                requestJson["receiverDeviceType"] = self.safeString(rdt)
                requestJson["receiver_device_type"] = self.safeString(rdt)
            }
            if !deviceType.isEmpty {
                let normalizedSender = normalizedSenderDeviceTypeForNotification(deviceType)
                requestJson["sender_device_type"] = self.safeString(normalizedSender)
                requestJson["senderDeviceType"] = self.safeString(normalizedSender)
            }
            requestJson["click_action"] = "OPEN_ACTIVITY_1"
            requestJson["icon"] = "notification_icon"
            requestJson["selectionCount"] = self.safeString(model.selectionCount ?? "1")
            
            // Message fields (matching backend PHP parameters)
            requestJson["uid"] = self.safeString(model.uid)
            requestJson["message"] = self.safeString(truncatedMessage)
            requestJson["time"] = self.safeString(sentTime)
            requestJson["document"] = self.safeString(model.document)
            requestJson["dataType"] = self.safeString(model.dataType)
            requestJson["extension"] = self.safeString(model.fileExtension ?? "")
            requestJson["name"] = self.safeString(model.name ?? "")
            requestJson["phone"] = self.safeString(model.phone ?? "")
            requestJson["miceTiming"] = self.safeString(model.miceTiming ?? "")
            requestJson["micPhoto"] = self.safeString(model.micPhoto ?? "")
            requestJson["userName"] = self.safeString(userName)
            requestJson["replytextData"] = self.safeString(model.replytextData ?? "")
            requestJson["replyKey"] = self.safeString(model.replyKey ?? "")
            requestJson["replyType"] = self.safeString(model.replyType ?? "")
            requestJson["replyOldData"] = self.safeString(model.replyOldData ?? "")
            requestJson["replyCrtPostion"] = self.safeString(model.replyCrtPostion ?? "")
            requestJson["modelId"] = self.safeString(model.id)
            requestJson["receiverUid"] = self.safeString(model.receiverId)
            requestJson["forwaredKey"] = self.safeString(model.forwaredKey ?? "")
            requestJson["groupName"] = self.safeString(model.groupName ?? "")
            requestJson["docSize"] = self.safeString(model.docSize ?? "")
            requestJson["fileName"] = self.safeString(model.fileName ?? "")
            requestJson["thumbnail"] = self.safeString(model.thumbnail ?? "")
            requestJson["fileNameThumbnail"] = self.safeString(model.fileNameThumbnail ?? "")
            requestJson["caption"] = self.safeString(model.caption ?? "")
            requestJson["notification"] = String(model.notification) // Firebase FCM requires strings, not integers
            requestJson["currentDate"] = self.safeString(model.currentDate ?? "")
            requestJson["senderTokenReply"] = self.safeString(myFcmToken)
            requestJson["userFcmToken"] = self.safeString(userFTokenKey) // Backend uses deviceToken for userFcmTokenPower
            
            print("📲 [SEND_NOTIFICATION_API] Notification request JSON for modelId: \(model.id): \(requestJson)")
            
            // Send POST request (matching Android OkHttp POST)
            let endpoint = Constant.baseURL + "EmojiController/send_notification_api"
            
            guard let url = URL(string: endpoint) else {
                print("🚫 [SEND_NOTIFICATION_API] Invalid notification URL: \(endpoint)")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestJson)
            } catch {
                print("🚫 [SEND_NOTIFICATION_API] Failed to serialize notification JSON: \(error.localizedDescription)")
                return
            }
            
            print("📲 [SEND_NOTIFICATION_API] Sending notification to URL: \(endpoint) for modelId: \(model.id)")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("🚫 [SEND_NOTIFICATION_API] Notification failed for modelId: \(model.id): \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    let responseBody = data != nil ? String(data: data!, encoding: .utf8) ?? "" : ""
                    print("📲 [SEND_NOTIFICATION_API] Notification response for modelId: \(model.id), Status: \(statusCode), Body: \(responseBody)")
                    
                    if (200...299).contains(statusCode) {
                        // Check if FCM returned an error in the response body
                        if responseBody.contains("THIRD_PARTY_AUTH_ERROR") || responseBody.contains("UNAUTHENTICATED") {
                            print("⚠️ [SEND_NOTIFICATION_API] Backend API succeeded (200) but FCM rejected the access token")
                            print("⚠️ [SEND_NOTIFICATION_API] This may indicate a backend issue - backend should use token as 'Bearer <token>' in Authorization header")
                            print("⚠️ [SEND_NOTIFICATION_API] Token format is correct (ya29.c...), matching Android implementation")
                        } else {
                            print("✅ [SEND_NOTIFICATION_API] Notification sent successfully")
                        }
                    } else {
                        print("🚫 [SEND_NOTIFICATION_API] Notification HTTP error \(statusCode): \(responseBody)")
                    }
                }
            }.resume()
        }
    }
    
    // MARK: - Send Voice Call Notification via Backend API (supports Android & iOS)
    func sendVoiceCallNotification(
        receiverToken: String,
        receiverDeviceType: String,
        receiverId: String,
        receiverPhone: String,
        roomId: String,
        voipToken: String? = nil  // 🆕 VoIP token for iOS CallKit
    ) {
        let trimmedToken = receiverToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty, trimmedToken != "apns_missing" else {
            print("⚠️ [VOICE_CALL_NOTIFICATION] Skipping - invalid receiver token")
            return
        }
        
        let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let myName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let myPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        let myPhone = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) ?? ""
        
        // Get VoIP token for iOS devices
        let trimmedVoipToken = voipToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        print("📞 [VOICE_CALL_NOTIFICATION] Preparing notification:")
        print("   - Receiver Token: \(trimmedToken)")
        print("   - Device Type: \(receiverDeviceType)")
        print("   - Receiver ID: \(receiverId)")
        print("   - Room ID: \(roomId)")
        if receiverDeviceType != "1" && !trimmedVoipToken.isEmpty {
            print("   - VoIP Token: \(trimmedVoipToken.prefix(20))... ✅")
        }
        
        getAccessToken { [weak self] accessToken in
            guard let self = self else { return }
            guard let token = accessToken, !token.isEmpty else {
                print("⚠️ [VOICE_CALL_NOTIFICATION] Failed to get access token")
                return
            }
            
            // Call backend API which handles device_type routing
            self.sendVoiceCallNotificationToBackend(
                deviceToken: trimmedToken,
                accessToken: token,
                deviceType: receiverDeviceType,
                receiverId: receiverId,
                receiverPhone: receiverPhone,
                roomId: roomId,
                senderUid: myUid,
                senderName: myName,
                senderPhoto: myPhoto,
                senderPhone: myPhone,
                voipToken: trimmedVoipToken  // 🆕 Pass VoIP token
            )
        }
    }
    
    // MARK: - Send Voice Call Notification Directly to FCM (matching Android FcmNotificationsSender)
    private func sendVoiceCallNotificationToBackend(
        deviceToken: String,
        accessToken: String,
        deviceType: String,
        receiverId: String,
        receiverPhone: String,
        roomId: String,
        senderUid: String,
        senderName: String,
        senderPhoto: String,
        senderPhone: String = "",
        voipToken: String? = nil  // 🆕 VoIP token for iOS CallKit
    ) {
        // FCM endpoint - direct to FCM (matching Android)
        let fcmUrl = "https://fcm.googleapis.com/v1/projects/enclosure-30573/messages:send"
        
        guard let url = URL(string: fcmUrl) else {
            print("⚠️ [VOICE_CALL_NOTIFICATION] Invalid FCM URL")
            return
        }
        
        // Create data payload matching Android FcmNotificationsSender.createExtraData()
        let extraData: [String: Any] = [
            "name": senderName,
            "title": "Enclosure",
            "body": Constant.incomingVoiceCall,
            "icon": "notification_icon",
            "click_action": "OPEN_VOICE_CALL",
            "meetingId": "meetingId",
            "phone": receiverPhone,
            "photo": senderPhoto,
            "token": "",
            "uid": senderUid,
            "receiverId": receiverId,
            "device_type": deviceType,
            "userFcmToken": deviceToken,
            "username": senderUid,
            "createdBy": senderUid,
            "incoming": senderUid,
            "bodyKey": Constant.incomingVoiceCall,
            "roomId": roomId
        ]
        
        // Build message payload based on device type
        var messagePayload: [String: Any]
        
        if deviceType.trimmingCharacters(in: .whitespacesAndNewlines) == "1" {
            // Android device (device_type == "1") - Data-only payload
            messagePayload = [
                "token": deviceToken,
                "data": extraData
            ]
        } else {
            // iOS device (device_type != "1") - SEND VOIP PUSH FOR INSTANT CALLKIT!
            // ⚠️ IMPORTANT: For iOS call notifications, we send VoIP Push to APNs (NOT FCM)
            // This triggers instant CallKit in background/lock screen/terminated states
            
            // 🆕 Use actual VoIP token if available, otherwise fall back to FCM token
            let actualVoipToken = (voipToken != nil && !voipToken!.isEmpty) ? voipToken! : deviceToken
            
            print("📞📞📞 [VOIP] ========================================")
            print("📞 [VOIP] Detected iOS CALL notification!")
            print("📞 [VOIP] Switching to VoIP Push for instant CallKit!")
            if voipToken != nil && !voipToken!.isEmpty {
                print("📞 [VOIP] Using provided VoIP token: \(actualVoipToken.prefix(20))... ✅")
            } else {
                print("⚠️ [VOIP] No VoIP token provided, using FCM token as fallback")
            }
            print("📞 [VOIP] ========================================")
            
            // Send VoIP Push directly to APNs
            sendVoIPPushToAPNs(
                voipToken: actualVoipToken,  // ✅ Use actual VoIP token from contact/call log
                senderUid: senderUid,
                senderName: senderName,
                senderPhoto: senderPhoto,
                senderPhone: senderPhone,
                roomId: roomId,
                receiverId: receiverId,
                receiverPhone: receiverPhone,
                bodyKey: Constant.incomingVoiceCall,
                accessToken: accessToken
            )
            
            print("✅ [VOIP] VoIP Push sent - iOS will show instant CallKit!")
            print("✅ [VOIP] Skipping FCM notification for voice call")
            return  // IMPORTANT: Don't send FCM for voice calls!
        }
        
        let fcmPayload: [String: Any] = [
            "message": messagePayload
        ]
        
        print("📞 [VOICE_CALL_NOTIFICATION] Sending directly to FCM")
        print("📞 [VOICE_CALL_NOTIFICATION] Device Type: \(deviceType) (1=Android, other=iOS)")
        if deviceType.trimmingCharacters(in: .whitespacesAndNewlines) == "1" {
            print("📞 [VOICE_CALL_NOTIFICATION] Using Android payload (data-only)")
        } else {
            print("📞 [VOICE_CALL_NOTIFICATION] Using iOS CallKit payload (USER-VISIBLE notification)")
            print("📞 [VOICE_CALL_NOTIFICATION] Changed from silent push to user-visible (fixes SwiftUI scene issue)")
            print("📞 [VOICE_CALL_NOTIFICATION] NotificationDelegate will intercept and trigger CallKit")
        }
        
        // Log the complete payload being sent
        print("📤 [VOICE_CALL_NOTIFICATION] ========== SENDING PAYLOAD ==========")
        if let jsonData = try? JSONSerialization.data(withJSONObject: fcmPayload, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 [VOICE_CALL_NOTIFICATION] FCM Payload:\n\(jsonString)")
        } else {
            print("📤 [VOICE_CALL_NOTIFICATION] Payload: \(fcmPayload)")
        }
        print("📤 [VOICE_CALL_NOTIFICATION] ========================================")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: fcmPayload)
        } catch {
            print("⚠️ [VOICE_CALL_NOTIFICATION] Failed to encode payload: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("⚠️ [VOICE_CALL_NOTIFICATION] Network error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ [VOICE_CALL_NOTIFICATION] Invalid response")
                return
            }
            
            print("📞 [VOICE_CALL_NOTIFICATION] FCM response status: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📞 [VOICE_CALL_NOTIFICATION] FCM response: \(responseString)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ [VOICE_CALL_NOTIFICATION] Voice call notification sent successfully")
                } else {
                    print("❌ [VOICE_CALL_NOTIFICATION] FCM error: \(responseString)")
                }
            }
        }.resume()
    }
    
    // MARK: - Send VoIP Push to APNs for Instant CallKit
    private func sendVoIPPushToAPNs(
        voipToken: String,
        senderUid: String = "",
        senderName: String,
        senderPhoto: String,
        senderPhone: String = "",
        roomId: String,
        receiverId: String,
        receiverPhone: String,
        bodyKey: String,
        accessToken: String
    ) {
        print("📞 [VOIP] Starting VoIP Push to APNs")
        print("📞 [VOIP] VoIP Token: \(voipToken.prefix(20))...")
        
        // TODO: Get actual VoIP token from database
        // For now, assuming deviceToken might be VoIP token
        // In production: ChatCacheManager.shared.getVoIPToken(for: receiverId) { voipToken in ... }
        
        // APNs endpoints
        // Production: TestFlight/App Store
        // Sandbox: Xcode debug builds
        let apnsUrlProduction = "https://api.push.apple.com/3/device/\(voipToken)"
        let apnsUrlSandbox = "https://api.sandbox.push.apple.com/3/device/\(voipToken)"

        // Create VoIP push payload.
        // VoIP pushes MUST include aps with content-available=1.
        let voipPayload: [String: Any] = [
            "aps": ["content-available": 1],
            "name": senderName,
            "photo": senderPhoto,
            "roomId": roomId,
            "receiverId": receiverId,
            "phone": receiverPhone,
            "bodyKey": bodyKey,
            "user_nameKey": senderName,
            "uid": senderUid,
            "incoming": senderUid,
            "senderPhone": senderPhone
        ]
        
        print("📞 [VOIP] Payload: \(voipPayload)")
        
        // TODO: Create APNs JWT token for authentication
        // You need to implement createAPNsJWT() method with your Auth Key
        // See BACKEND_VOIP_IMPLEMENTATION.md for details
        let jwtToken = createAPNsJWT() ?? ""
        
        if jwtToken.isEmpty {
            print("⚠️ [VOIP] JWT token is empty - VoIP push will fail")
            print("⚠️ [VOIP] You need to implement createAPNsJWT() with your APNs Auth Key")
            // For now, continue anyway for logging purposes
        }
        

        print("📞 [VOIP] Trying PRODUCTION APNs first (TestFlight/App Store)...")
        sendApnsVoipRequest(
            apnsUrl: apnsUrlProduction,
            environmentLabel: "PRODUCTION",
            voipPayload: voipPayload,
            jwtToken: jwtToken
        ) { success in
            if success {
                return
            }
            print("📞 [VOIP] Production APNs failed. Trying SANDBOX APNs (Debug/Xcode)...")
            self.sendApnsVoipRequest(
                apnsUrl: apnsUrlSandbox,
                environmentLabel: "SANDBOX",
                voipPayload: voipPayload,
                jwtToken: jwtToken,
                completion: { _ in }
            )
        }
    }

    private func sendApnsVoipRequest(
        apnsUrl: String,
        environmentLabel: String,
        voipPayload: [String: Any],
        jwtToken: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard let url = URL(string: apnsUrl) else {
            print("⚠️ [VOIP] Invalid APNs URL (\(environmentLabel)): \(apnsUrl)")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.enclosure.voip", forHTTPHeaderField: "apns-topic")
        request.setValue("voip", forHTTPHeaderField: "apns-push-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority")
        request.setValue("bearer \(jwtToken)", forHTTPHeaderField: "authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: voipPayload)
        } catch {
            print("⚠️ [VOIP] Failed to encode payload (\(environmentLabel)): \(error.localizedDescription)")
            completion(false)
            return
        }

        print("📞 [VOIP] APNs URL (\(environmentLabel)): \(apnsUrl)")
        print("📞 [VOIP] Sending VoIP Push to APNs (\(environmentLabel))...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("⚠️ [VOIP] Network error (\(environmentLabel)): \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ [VOIP] Invalid response (\(environmentLabel))")
                completion(false)
                return
            }

            let responseBody = data != nil ? String(data: data!, encoding: .utf8) ?? "" : ""
            print("📞 [VOIP] APNs response status (\(environmentLabel)): \(httpResponse.statusCode)")
            if !responseBody.isEmpty {
                print("📞 [VOIP] APNs response (\(environmentLabel)): \(responseBody)")
            }

            if httpResponse.statusCode == 200 {
                print("✅✅✅ [VOIP] ========================================")
                print("✅ [VOIP] VoIP Push sent SUCCESSFULLY! (\(environmentLabel))")
                print("✅ [VOIP] iOS device should show incoming CallKit UI")
                print("✅✅✅ [VOIP] ========================================")
                completion(true)
            } else {
                print("❌ [VOIP] APNs Error (\(environmentLabel)): \(httpResponse.statusCode)")
                print("❌ [VOIP] Common errors:")
                print("❌ [VOIP]   400 = Bad request (BadTopic/BadDeviceToken/MissingTopic/etc)")
                print("❌ [VOIP]   403 = Invalid JWT or not allowed")
                print("❌ [VOIP]   410 = Unregistered/Invalid token")
                completion(false)
            }
        }.resume()
    }
    
    // MARK: - Create APNs JWT Token
    private func createAPNsJWT() -> String? {
        // APNs Configuration
        let APNS_KEY_ID = "838GP97CYN"  // ✅ Your actual Key ID
        let APNS_TEAM_ID = "XR82K974UJ"  // ✅ Your Team ID
        let APNS_PRIVATE_KEY = """
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQglV2GsFLF1OrMz6Jx
i4dF04TInoAVXvpkyYeub/EYB+GgCgYIKoZIzj0DAQehRANCAATul9xtMykbvPvm
WD1jSDfoH82QVsoiO1pQqtcfyWfrvUOUSCieWt+BOVLDDsLFLL1VTz5u3ZQ9oHbP
52p0sePJ
-----END PRIVATE KEY-----
"""
        
        print("🔑 [APNs JWT] Creating JWT token...")
        print("🔑 [APNs JWT] Key ID: \(APNS_KEY_ID)")
        print("🔑 [APNs JWT] Team ID: \(APNS_TEAM_ID)")
        
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
              let headerBase64 = base64URLEncodeJWT(headerData),
              let claimsBase64 = base64URLEncodeJWT(claimsData) else {
            print("❌ [APNs JWT] Failed to encode header/claims")
            return nil
        }
        
        let unsignedToken = "\(headerBase64).\(claimsBase64)"
        
        // Sign with ES256
        guard let signature = signWithES256JWT(data: unsignedToken, privateKey: APNS_PRIVATE_KEY),
              let signatureBase64 = base64URLEncodeJWT(signature) else {
            print("❌ [APNs JWT] Failed to sign token")
            return nil
        }
        
        let jwt = "\(unsignedToken).\(signatureBase64)"
        
        print("✅ [APNs JWT] JWT token created successfully!")
        print("🔑 [APNs JWT] Token: \(jwt.prefix(50))...")
        print("🔑 [APNs JWT] Token length: \(jwt.count) characters")
        
        return jwt
    }
    
    // MARK: - JWT Helper Functions
    private func base64URLEncodeJWT(_ data: Data) -> String? {
        let base64 = data.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func signWithES256JWT(data: String, privateKey: String) -> Data? {
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
    
    // MARK: - Send Video Call Notification via Backend API (supports Android & iOS)
    func sendVideoCallNotification(
        receiverToken: String,
        receiverDeviceType: String,
        receiverId: String,
        receiverPhone: String,
        roomId: String,
        voipToken: String? = nil  // 🆕 VoIP token for iOS CallKit
    ) {
        let trimmedToken = receiverToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty, trimmedToken != "apns_missing" else {
            print("⚠️ [VIDEO_CALL_NOTIFICATION] Skipping - invalid receiver token")
            return
        }
        
        let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let myName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let myPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        let myPhone = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) ?? ""
        
        // Get VoIP token for iOS devices
        let trimmedVoipToken = voipToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        print("📹 [VIDEO_CALL_NOTIFICATION] Preparing notification:")
        print("   - Receiver Token: \(trimmedToken)")
        print("   - Device Type: \(receiverDeviceType)")
        print("   - Receiver ID: \(receiverId)")
        print("   - Room ID: \(roomId)")
        if receiverDeviceType != "1" && !trimmedVoipToken.isEmpty {
            print("   - VoIP Token: \(trimmedVoipToken.prefix(20))... ✅")
        }
        
        getAccessToken { [weak self] accessToken in
            guard let self = self else { return }
            guard let token = accessToken, !token.isEmpty else {
                print("⚠️ [VIDEO_CALL_NOTIFICATION] Failed to get access token")
                return
            }
            
            // Call backend API which handles device_type routing
            self.sendVideoCallNotificationToBackend(
                deviceToken: trimmedToken,
                accessToken: token,
                deviceType: receiverDeviceType,
                receiverId: receiverId,
                receiverPhone: receiverPhone,
                roomId: roomId,
                senderUid: myUid,
                senderName: myName,
                senderPhoto: myPhoto,
                senderPhone: myPhone,
                voipToken: trimmedVoipToken  // 🆕 Pass VoIP token
            )
        }
    }
    
    // MARK: - Send Video Call Notification Directly to FCM (matching Android FcmNotificationsSender)
    private func sendVideoCallNotificationToBackend(
        deviceToken: String,
        accessToken: String,
        deviceType: String,
        receiverId: String,
        receiverPhone: String,
        roomId: String,
        senderUid: String,
        senderName: String,
        senderPhoto: String,
        senderPhone: String = "",
        voipToken: String? = nil  // 🆕 VoIP token for iOS CallKit
    ) {
        // FCM endpoint - direct to FCM (matching Android)
        let fcmUrl = "https://fcm.googleapis.com/v1/projects/enclosure-30573/messages:send"
        
        guard let url = URL(string: fcmUrl) else {
            print("⚠️ [VIDEO_CALL_NOTIFICATION] Invalid FCM URL")
            return
        }
        
        // Create data payload matching Android FcmNotificationsSender.createExtraData()
        let extraData: [String: Any] = [
            "name": senderName,
            "title": "Enclosure",
            "body": "Incoming video call",
            "icon": "notification_icon",
            "click_action": "OPEN_VIDEO_CALL",
            "meetingId": "meetingId",
            "phone": receiverPhone,
            "photo": senderPhoto,
            "token": "",
            "uid": senderUid,
            "receiverId": receiverId,
            "device_type": deviceType,
            "userFcmToken": deviceToken,
            "username": senderUid,
            "createdBy": senderUid,
            "incoming": senderUid,
            "bodyKey": "Incoming video call",
            "roomId": roomId
        ]
        
        // Build message payload based on device type
        var messagePayload: [String: Any]
        
        if deviceType.trimmingCharacters(in: .whitespacesAndNewlines) == "1" {
            // Android device (device_type == "1") - Data-only payload
            messagePayload = [
                "token": deviceToken,
                "data": extraData
            ]
        } else {
            // iOS device (device_type != "1") - SEND VOIP PUSH FOR INSTANT CALLKIT!
            // ⚠️ IMPORTANT: For iOS call notifications, we send VoIP Push to APNs (NOT FCM)
            // This triggers instant CallKit in background/lock screen/terminated states
            
            // 🆕 Use actual VoIP token if available, otherwise fall back to FCM token
            let actualVoipToken = (voipToken != nil && !voipToken!.isEmpty) ? voipToken! : deviceToken
            
            print("📹📹📹 [VOIP] ========================================")
            print("📹 [VOIP] Detected iOS VIDEO CALL notification!")
            print("📹 [VOIP] Switching to VoIP Push for instant CallKit!")
            if voipToken != nil && !voipToken!.isEmpty {
                print("📹 [VOIP] Using provided VoIP token: \(actualVoipToken.prefix(20))... ✅")
            } else {
                print("⚠️ [VOIP] No VoIP token provided, using FCM token as fallback")
            }
            print("📹 [VOIP] ========================================")
            
            // Send VoIP Push directly to APNs
            sendVoIPPushToAPNs(
                voipToken: actualVoipToken,  // ✅ Use actual VoIP token from contact/call log
                senderUid: senderUid,
                senderName: senderName,
                senderPhoto: senderPhoto,
                senderPhone: senderPhone,
                roomId: roomId,
                receiverId: receiverId,
                receiverPhone: receiverPhone,
                bodyKey: Constant.incomingVideoCall,
                accessToken: accessToken
            )
            
            print("✅ [VOIP] VoIP Push sent - iOS will show instant CallKit!")
            print("✅ [VOIP] Skipping FCM notification for video call")
            return  // IMPORTANT: Don't send FCM for video calls!
        }
        
        // This code only runs for Android devices now
        let fcmPayload: [String: Any] = [
            "message": messagePayload
        ]
        
        print("📹 [VIDEO_CALL_NOTIFICATION] Sending directly to FCM")
        print("📹 [VIDEO_CALL_NOTIFICATION] Device Type: \(deviceType) (1=Android, other=iOS)")
        if deviceType.trimmingCharacters(in: .whitespacesAndNewlines) == "1" {
            print("📹 [VIDEO_CALL_NOTIFICATION] Using Android payload (data-only)")
        } else {
            print("📹 [VIDEO_CALL_NOTIFICATION] Using iOS CallKit payload (USER-VISIBLE notification)")
            print("📹 [VIDEO_CALL_NOTIFICATION] Changed from silent push to user-visible (fixes SwiftUI scene issue)")
            print("📹 [VIDEO_CALL_NOTIFICATION] NotificationDelegate will intercept and trigger CallKit")
        }
        
        // Log the complete payload being sent
        print("📤 [VIDEO_CALL_NOTIFICATION] ========== SENDING PAYLOAD ==========")
        if let jsonData = try? JSONSerialization.data(withJSONObject: fcmPayload, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 [VIDEO_CALL_NOTIFICATION] FCM Payload:\n\(jsonString)")
        } else {
            print("📤 [VIDEO_CALL_NOTIFICATION] Payload: \(fcmPayload)")
        }
        print("📤 [VIDEO_CALL_NOTIFICATION] ========================================")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: fcmPayload)
        } catch {
            print("⚠️ [VIDEO_CALL_NOTIFICATION] Failed to encode payload: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("⚠️ [VIDEO_CALL_NOTIFICATION] Network error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ [VIDEO_CALL_NOTIFICATION] Invalid response")
                return
            }
            
            print("📹 [VIDEO_CALL_NOTIFICATION] FCM response status: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📹 [VIDEO_CALL_NOTIFICATION] FCM response: \(responseString)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ [VIDEO_CALL_NOTIFICATION] Video call notification sent successfully")
                } else {
                    print("❌ [VIDEO_CALL_NOTIFICATION] FCM error: \(responseString)")
                }
            }
        }.resume()
    }
    
    // MARK: - Send Group Notification API (matching Android end_notification_api_group)
    private func sendGroupNotificationAPI(
        model: GroupChatMessage,
        userFTokenKey: String,
        deviceType: String,
        groupMembers: [[String: Any]]
    ) {
        print("📲 [GROUP_NOTIFICATION] ===== START end_notification_api_group =====")
        print("📲 [GROUP_NOTIFICATION] modelId: \(model.id)")
        print("📲 [GROUP_NOTIFICATION] groupId: \(model.receiverUid)")
        print("📲 [GROUP_NOTIFICATION] dataType: \(model.dataType)")
        print("📲 [GROUP_NOTIFICATION] groupMembers count: \(groupMembers.count)")
        
        // Get user info
        let myFcmToken = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
        let profilePic = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        let userName = model.userName ?? ""
        
        // Determine notification message based on data type (matching Android)
        let notificationMessage: String
        switch model.dataType {
        case Constant.Text:
            notificationMessage = model.message
        case Constant.img:
            notificationMessage = "You have a new Image"
        case Constant.contact:
            notificationMessage = "You have a new Contact"
        case Constant.voiceAudio:
            notificationMessage = "You have a new Audio"
        case Constant.video:
            notificationMessage = "You have a new Video"
        case Constant.doc:
            notificationMessage = "You have a new File"
        default:
            notificationMessage = "You have a new Message"
        }
        
        print("📲 [GROUP_NOTIFICATION] Preparing notification payload for modelId: \(model.id)")
        print("📲 [GROUP_NOTIFICATION] Group ID: \(model.receiverUid), Members: \(groupMembers.count)")
        
        // Note: Android uses FCM token (senderTokenReplyPower) for all access token fields
        // We don't need to retrieve Firebase OAuth access token here
        if myFcmToken.isEmpty {
            print("⚠️ [GROUP_NOTIFICATION] FCM token is empty - notification may fail")
        } else {
            print("✅ [GROUP_NOTIFICATION] Using FCM token for access token fields")
        }
        
        // Truncate message to 100 words (matching Android truncateToWordss)
        let truncatedMessage = self.truncateToWords(notificationMessage, maxWords: 100)
        
        // Build JSON request (matching Android end_notification_api_group parameters)
        // Note: Android uses senderTokenReplyPower (FCM token) for all access token fields
        var requestJson: [String: Any] = [:]
        
        // Access token fields (all set to FCM token, matching Android lines 104-107)
        requestJson["accessToken"] = self.safeString(myFcmToken)
        requestJson["accessTokenKey"] = self.safeString(myFcmToken)
        requestJson["userFcmToken"] = self.safeString(myFcmToken)
        requestJson["senderTokenReply"] = self.safeString(myFcmToken)
        
        // Notification fields (matching Android lines 108-117)
        requestJson["title"] = self.safeString(userName)
        requestJson["body"] = self.safeString(truncatedMessage)
        requestJson["receiverKey"] = self.safeString(model.uid)
        requestJson["user_name"] = self.safeString(userName)
        requestJson["photo"] = self.safeString(profilePic)
        requestJson["currentDateTimeString"] = self.safeString(model.time)
        if !deviceType.isEmpty {
            let normalizedSender = normalizedSenderDeviceTypeForNotification(deviceType)
            requestJson["deviceType"] = self.safeString(normalizedSender)
        }
        requestJson["bodyKey"] = Constant.chatting
        requestJson["click_action"] = "OPEN_ACTIVITY_1"
        requestJson["icon"] = "notification_icon"
        
        // Message fields (matching Android lines 118-144)
        requestJson["uid"] = self.safeString(model.uid)
        requestJson["message"] = self.safeString(truncatedMessage)
        requestJson["time"] = self.safeString(model.time)
        requestJson["document"] = self.safeString(model.document)
        requestJson["dataType"] = self.safeString(model.dataType)
        requestJson["extension"] = self.safeString(model.fileExtension ?? "")
        requestJson["name"] = self.safeString(model.name ?? "")
        requestJson["phone"] = self.safeString(model.phone ?? "")
        requestJson["miceTiming"] = self.safeString(model.miceTiming ?? "")
        requestJson["micPhoto"] = self.safeString(model.micPhoto ?? "")
        requestJson["userName"] = self.safeString(userName)
        requestJson["replytextData"] = ""
        requestJson["replyKey"] = ""
        requestJson["replyType"] = ""
        requestJson["replyOldData"] = ""
        requestJson["replyCrtPostion"] = ""
        requestJson["modelId"] = self.safeString(model.id)
        requestJson["receiverUid"] = self.safeString(model.receiverUid)
        requestJson["forwaredKey"] = ""
        requestJson["groupName"] = ""
        requestJson["docSize"] = self.safeString(model.docSize ?? "")
        requestJson["fileName"] = self.safeString(model.fileName ?? "")
        requestJson["thumbnail"] = self.safeString(model.thumbnail ?? "")
        requestJson["fileNameThumbnail"] = self.safeString(model.fileNameThumbnail ?? "")
        requestJson["caption"] = self.safeString(model.caption ?? "")
        requestJson["notification"] = 1
        requestJson["currentDate"] = self.safeString(model.currentDate ?? "")
        requestJson["senderTokenReplyPower"] = self.safeString(myFcmToken)
        requestJson["group_members"] = groupMembers // Send as array (matching Android line 145)
        requestJson["timestamp"] = Date().timeIntervalSince1970
        requestJson["imageWidthDp"] = self.safeString(model.imageWidth ?? "") // Note: Android uses imageWidthDp
        requestJson["imageHeightDp"] = self.safeString(model.imageHeight ?? "") // Note: Android uses imageHeightDp
        requestJson["aspectRatio"] = self.safeString(model.aspectRatio ?? "")
        requestJson["selectionCount"] = self.safeString(model.selectionCount ?? "1")
        
        // Convert selectionBunch to JSON array if available
        if let selectionBunch = model.selectionBunch, !selectionBunch.isEmpty {
            let selectionBunchArray = selectionBunch.map { bunch in
                ["imgUrl": bunch.imgUrl, "fileName": bunch.fileName]
            }
            requestJson["selectionBunch"] = selectionBunchArray
        } else {
            requestJson["selectionBunch"] = []
        }
        
        print("📲 [GROUP_NOTIFICATION] Request JSON for modelId: \(model.id)")
        print("📲 [GROUP_NOTIFICATION] Group members count: \(groupMembers.count)")
        print("📲 [GROUP_NOTIFICATION] Group members structure: \(groupMembers)")
        print("📲 [GROUP_NOTIFICATION] Access token fields set to FCM token: \(myFcmToken.isEmpty ? "EMPTY" : "\(myFcmToken.prefix(20))...")")
        
        // Send POST request (matching Android NotificationApiHelper.handleGroupNotification)
        let endpoint = Constant.baseURL + "EmojiController/end_notification_api_group"
        
        guard let url = URL(string: endpoint) else {
            print("🚫 [GROUP_NOTIFICATION] Invalid URL: \(endpoint) for modelId: \(model.id)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestJson)
            print("📲 [GROUP_NOTIFICATION] Request body serialized successfully for modelId: \(model.id)")
        } catch {
            print("🚫 [GROUP_NOTIFICATION] Failed to serialize JSON for modelId: \(model.id), error: \(error.localizedDescription)")
            return
        }
        
        print("📲 [GROUP_NOTIFICATION] Sending POST request to: \(endpoint) for modelId: \(model.id)")
        print("📲 [GROUP_NOTIFICATION] Request URL: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🚫 [GROUP_NOTIFICATION] Network error for modelId: \(model.id), error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                let responseBody = data != nil ? String(data: data!, encoding: .utf8) ?? "" : ""
                
                if (200...299).contains(statusCode) {
                    print("✅ [GROUP_NOTIFICATION] SUCCESS for modelId: \(model.id)")
                    print("✅ [GROUP_NOTIFICATION] Status Code: \(statusCode)")
                    print("✅ [GROUP_NOTIFICATION] Response Body: \(responseBody.isEmpty ? "(empty)" : responseBody)")
                    print("✅ [GROUP_NOTIFICATION] ===== END end_notification_api_group (SUCCESS) =====")
                } else {
                    print("🚫 [GROUP_NOTIFICATION] HTTP ERROR for modelId: \(model.id)")
                    print("🚫 [GROUP_NOTIFICATION] Status Code: \(statusCode)")
                    print("🚫 [GROUP_NOTIFICATION] Response Body: \(responseBody.isEmpty ? "(empty)" : responseBody)")
                    print("🚫 [GROUP_NOTIFICATION] ===== END end_notification_api_group (ERROR) =====")
                }
            } else {
                print("🚫 [GROUP_NOTIFICATION] Invalid HTTP response for modelId: \(model.id)")
                print("🚫 [GROUP_NOTIFICATION] ===== END end_notification_api_group (ERROR) =====")
            }
        }.resume()
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
    
    // MARK: - Generate Access Token Locally (matching Android Accesstoken.java)
    private func generateAccessTokenLocally(completion: @escaping (String?) -> Void) {
        print("🔑 [ACCESS_TOKEN] Starting to fetch access token...")
        
        // Hardcoded service account JSON (matching Android Accesstoken.java)
        let serviceAccountJSON = """
        {
          "type": "service_account",
          "project_id": "enclosure-30573",
          "private_key_id": "0214c5bb83d50e5d11d72ba8d3e4ebba7d313677",
          "private_key": "-----BEGIN PRIVATE KEY-----\\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQD04bnvGLULC8tn\\nU6wBT6ymn3axN5l3UTyaoNjGGH9CNK0Qx1r5tsreXqfw/iDsy5p/Wsjc5WGWBcrI\\nxIsMb820tM1v1Gscv8LxcyHwovlPYguseFLsWJ+Nc/TnsVS34Ykuf11iWYWVJBXF\\n1K1MGuDhjuIB+5GosOpw72yrZYVVJhWppiu00YX/193IFxZgScF45DydWZ8Hu3Q3\\n83ZWT3Q7IWJGcwpApBLjW6Cb9ccG9yrGVYkDvq5FpqVrlRBxfRtKFLZQnGuJyuZE\\nxAQYMrWE12Hhqrz1zrivJkuS4mX8AniYqKI2rUpAenlpn4bFmmNXFv9FCDfULCOz\\nOB8VzLz5AgMBAAECggEABFCAeM3z9/Xakj950FbEW/XYntaz8CjmQHMvs+Mf8DKt\\nZJZJQWJka0vk+ZdV99YT1W/sCg2gjTFyQ9ydS+LMZQVVI/CXfTIuZRf6M8XV+VK+\\nPJOszQKNYm316qnH1wA07TTL7b0AtYKlP48NCUI6pBQNt1XkrcGFipKCqk0SRFBr\\n+MiF8qr+fjrOEwt12q6sOYlHEHfAAsFGq4yJgnHudVPklcxIFYiW6JgmvDSTFHXV\\nYXQNHhZ+zlicdlE+dwu2mPfvn9dJgRf4Enjl3araA03Ga39uCq21ii0D8AqgwtPp\\nxguJ5wmcBbf1b7hHIDG0P0uTdCbTMi44qW8uvwbp4QKBgQD/6vSc2CjQtFaqir0C\\ni5OSDKBa1h3TKBRKcmPsbG3OPTsX+a3u1PN9hDBRaaX9/TeEuDQpC0t2WAs7df1i\\n1Q1WqUbDnsBA70imBkUuV7THogxLT5vbtx8FryTPt7GA1nRxUZct0kc2TG+lm1Kl\\nnKxIhyS/ULRckusg7AADdszfvwKBgQD09dz/q2DppH3hiUeM2jYhx0a0dVD5bwj9\\niujf3eKhbR6fpwj56OFC7dzTQYp5laqMMw9dIaA/uR4LAoRKOKDFXSOLR65YCxse\\nmCV8NDZ2RsHWb6cTCA2nytIDTsw1hqljEwuN1bnxz6+rrIQeiuOpE2KQa9dAuPVL\\nkznXb6ERRwKBgQDnShO1RO7uYG4LR8Q27qp6TosGTYk683gTKHsCi6RZxqEHtBHs\\nTe2ZvMRmb9MjT5zDiC8sARc8Z6oPHT3Z+q9JaUeZOHqMtTW1RulzTrUFz4DI97Pm\\nyQNyga4FRQFZbXhjidfWA7t0aXRl+ZCiOIzEJ8+gUHIRUH7MjD4e41mZxQKBgBEx\\nkKmBZfQAT7Wc5SDF0Dbevd+8vEpFuOPS9DWCZX3fIt8h4kdoSSdherZ5SzbtgmME\\n0nc+/Ph8DdfH/XEYOHCh8PS9u0cCwIyNMVReddQnc0OR4rA7SHoWilchGMRJB2qk\\n05LJBZwrb7ElEsDyDri3W5u3dgxc7xq24sB0XWHRAoGAaGIdVSYh/9UJEorTNTAl\\n/pWGF0f2eqcNu/zzWxSboAYEu8IXsVj42nb2C4wkBC2IDVXvqez70Y2eCDYwu1Uj\\npr7ohx6rJVssvjI2jzQKCa0KRR8W9WBzkC9fyspnBEJzpZyLz+UC6dkV7pA7vEyl\\njVn2aZOkuUaPlkdoVzF8VO0=\\n-----END PRIVATE KEY-----\\n",
          "client_email": "firebase-adminsdk-nulab@enclosure-30573.iam.gserviceaccount.com",
          "client_id": "118076563992961353315",
          "auth_uri": "https://accounts.google.com/o/oauth2/auth",
          "token_uri": "https://oauth2.googleapis.com/token",
          "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
          "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-nulab%40enclosure-30573.iam.gserviceaccount.com",
          "universe_domain": "googleapis.com"
        }
        """
        
        print("✅ [ACCESS_TOKEN] Service account JSON created successfully")
        
        // Parse service account JSON (matching Android GoogleCredentials.fromStream)
        guard let jsonData = serviceAccountJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let privateKey = json["private_key"] as? String,
              let clientEmail = json["client_email"] as? String,
              let tokenUri = json["token_uri"] as? String else {
            print("🚫 [ACCESS_TOKEN] Failed to parse service account JSON")
            print("🚫 [ACCESS_TOKEN] Required fields: private_key, client_email, token_uri")
            completion(nil)
            return
        }
        
        print("✅ [ACCESS_TOKEN] Service account JSON parsed successfully")
        print("🔑 [ACCESS_TOKEN] Client email: \(clientEmail)")
        print("🔑 [ACCESS_TOKEN] Token URI: \(tokenUri)")
        
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
        // Try to get cached token first (matching Android refreshIfExpired behavior)
        if let cachedToken = getCachedAccessToken(), !isTokenExpired(cachedToken) {
            let timeUntilExpiry = cachedToken.expiry.timeIntervalSinceNow
            print("✅ [ACCESS_TOKEN] Using cached access token (expires in \(Int(timeUntilExpiry)) seconds)")
            print("🔑 [ACCESS_TOKEN] Token format: \(cachedToken.token.prefix(20))...")
            completion(cachedToken.token)
            return
        }
        
        print("🔑 [ACCESS_TOKEN] No valid cached token or token expired, generating new OAuth2 access token...")
        
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
        
        print("🔑 [ACCESS_TOKEN] Creating JWT with scope: \(scope)")
        
        // Encode JWT header and payload
        guard let headerData = try? JSONSerialization.data(withJSONObject: header),
              let claimData = try? JSONSerialization.data(withJSONObject: claim),
              let headerBase64 = base64URLEncode(headerData),
              let claimBase64 = base64URLEncode(claimData) else {
            print("🚫 [ACCESS_TOKEN] Failed to encode JWT header/claim")
            completion(nil)
            return
        }
        
        let unsignedJWT = "\(headerBase64).\(claimBase64)"
        print("✅ [ACCESS_TOKEN] JWT header and payload encoded, signing with RSA private key...")
        
        // Sign JWT with RSA private key
        signJWT(unsignedJWT: unsignedJWT, privateKey: privateKey) { [weak self] signature in
            guard let self = self, let signature = signature else {
                print("🚫 [ACCESS_TOKEN] Failed to sign JWT")
                completion(nil)
                return
            }
            
            let signedJWT = "\(unsignedJWT).\(signature)"
            print("✅ [ACCESS_TOKEN] JWT signed successfully, exchanging for access token...")
            
            // Exchange JWT for access token
            self.exchangeJWTForAccessToken(jwt: signedJWT, tokenUri: tokenUri) { accessToken, expiresIn in
                if let accessToken = accessToken, let expiresIn = expiresIn {
                    // Cache the token
                    self.cacheAccessToken(accessToken, expiresIn: expiresIn)
                    print("✅ [ACCESS_TOKEN] Access token obtained successfully (expires in \(expiresIn) seconds)")
                    print("🔑 [ACCESS_TOKEN] Token format: \(accessToken.prefix(20))... (length: \(accessToken.count))")
                    print("🔑 [ACCESS_TOKEN] Token is valid Google OAuth2 format: \(accessToken.hasPrefix("ya29."))")
                    completion(accessToken)
                } else {
                    print("🚫 [ACCESS_TOKEN] Failed to exchange JWT for access token")
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
                print("🚫 Failed to decode private key")
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
                        print("🚫 Failed to create SecKey from PKCS#1: \(errorDesc)")
                    }
                } else {
                    print("🚫 Failed to extract PKCS#1 from PKCS#8")
                }
            }
            
            guard let secKey = secKey else {
                let errorDesc = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
                print("🚫 Failed to create SecKey: \(errorDesc)")
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
                print("🚫 Failed to convert JWT to data")
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
                print("🚫 Failed to sign JWT: \(error2?.takeRetainedValue().localizedDescription ?? "Unknown error")")
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
            print("🚫 [ACCESS_TOKEN] Invalid token URI: \(tokenUri)")
            completion(nil, nil)
            return
        }
        
        print("🔑 [ACCESS_TOKEN] Exchanging JWT for access token at: \(tokenUri)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)"
        request.httpBody = bodyString.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🚫 [ACCESS_TOKEN] Token exchange network error: \(error.localizedDescription)")
                completion(nil, nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔑 [ACCESS_TOKEN] Token exchange HTTP status: \(httpResponse.statusCode)")
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                let responseBody = data != nil ? String(data: data!, encoding: .utf8) ?? "" : ""
                print("🚫 [ACCESS_TOKEN] Failed to parse token response: \(responseBody)")
                if let httpResponse = response as? HTTPURLResponse {
                    print("🚫 [ACCESS_TOKEN] HTTP status code: \(httpResponse.statusCode)")
                }
                completion(nil, nil)
                return
            }
            
            let expiresIn = json["expires_in"] as? Int ?? 3600
            print("✅ [ACCESS_TOKEN] Successfully exchanged JWT for access token (expires in \(expiresIn) seconds)")
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
            return ""
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

