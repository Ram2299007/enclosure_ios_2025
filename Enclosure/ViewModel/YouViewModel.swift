//
//  youViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 08/05/25.
//

import Foundation

private enum YouCacheReason: CustomStringConvertible, Equatable {
    case prefetch
    case offline
    case error(String?)
    
    var description: String {
        switch self {
        case .prefetch:
            return "prefetch"
        case .offline:
            return "offline"
        case .error(let message):
            return "error(\(message ?? "nil"))"
        }
    }
}

class YouViewModel: ObservableObject {
    @Published var list: [GetProfileModel] = []
    @Published var listImages: [GetUserProfileImagesModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasCachedProfile = false
    @Published var hasCachedImages = false

    private let cacheManager = CallCacheManager.shared
    private let networkMonitor = NetworkMonitor.shared

    func fetch_profile_YouFragment(uid: String) {
        // Ensure @Published updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isLoading = true
            self.errorMessage = nil
        }

        loadCachedProfile(reason: .prefetch, shouldStopLoading: false)

        guard networkMonitor.isConnected else {
            loadCachedProfile(reason: .offline)
            return
        }

        ApiService.get_profile_YouFragment(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    let profiles = data ?? []
                    self.list = profiles
                    self.hasCachedProfile = !profiles.isEmpty
                    self.cacheManager.cacheYouProfiles(profiles)
                    // Only save device_type when it matches get_user_active_chat_list format ("1" or "2"), not UUID
                    if let first = profiles.first, !first.device_type.isEmpty, (first.device_type == "1" || first.device_type == "2") {
                        UserDefaults.standard.set(first.device_type, forKey: Constant.DEVICE_TYPE_KEY)
                    }
                } else {
                    if !self.hasCachedProfile {
                        self.loadCachedProfile(reason: .error(message))
                    } else {
                        self.errorMessage = message
                    }
                }
            }
        }
    }

    func fetch_user_profile_images_youFragment(uid: String) {
        // Ensure @Published updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isLoading = true
            self.errorMessage = nil
        }

        loadCachedImages(reason: .prefetch, shouldStopLoading: false)

        guard networkMonitor.isConnected else {
            loadCachedImages(reason: .offline)
            return
        }

        ApiService.get_user_profile_images_youFragment(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    let images = data ?? []
                    self.listImages = images
                    self.hasCachedImages = !images.isEmpty
                    self.cacheManager.cacheYouProfileImages(images)
                } else {
                    if !self.hasCachedImages {
                        self.loadCachedImages(reason: .error(message))
                    } else {
                        self.errorMessage = message
                    }
                }
            }
        }
    }

    private func loadCachedProfile(reason: YouCacheReason, shouldStopLoading: Bool = true) {
        cacheManager.fetchYouProfiles { [weak self] cachedProfiles in
            guard let self = self else { return }
            // Ensure all @Published property updates happen on main thread
            DispatchQueue.main.async {
                if cachedProfiles.isEmpty && reason == .prefetch {
                    if shouldStopLoading {
                        self.isLoading = false
                    }
                    return
                }

                self.list = cachedProfiles
                self.hasCachedProfile = !cachedProfiles.isEmpty
                if shouldStopLoading {
                    self.isLoading = false
                }

                switch reason {
                case .offline:
                    self.errorMessage = cachedProfiles.isEmpty ? "You are offline. No cached profile available." : nil
                case .prefetch:
                    break
                case .error(let message):
                    if cachedProfiles.isEmpty {
                        self.errorMessage = message?.isEmpty == false ? message : "Unable to load profile."
                    } else {
                        self.errorMessage = nil
                    }
                }

                print("👤 [YouViewModel] Loaded \(cachedProfiles.count) cached profiles for reason: \(reason)")
            }
        }
    }

    private func loadCachedImages(reason: YouCacheReason, shouldStopLoading: Bool = true) {
        cacheManager.fetchYouProfileImages { [weak self] cachedImages in
            guard let self = self else { return }
            // Ensure all @Published property updates happen on main thread
            DispatchQueue.main.async {
                if cachedImages.isEmpty && reason == .prefetch {
                    if shouldStopLoading {
                        self.isLoading = false
                    }
                    return
                }

                self.listImages = cachedImages
                self.hasCachedImages = !cachedImages.isEmpty
                if shouldStopLoading {
                    self.isLoading = false
                }

                switch reason {
                case .offline:
                    self.errorMessage = cachedImages.isEmpty ? "You are offline. No cached images available." : nil
                case .prefetch:
                    break
                case .error(let message):
                    if cachedImages.isEmpty {
                        self.errorMessage = message?.isEmpty == false ? message : "Unable to load profile images."
                    } else {
                        self.errorMessage = nil
                    }
                }

                print("👤 [YouViewModel] Loaded \(cachedImages.count) cached images for reason: \(reason)")
            }
        }
    }
}
