//
//  youViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 08/05/25.
//

import Foundation

class EditProfileViewModel: ObservableObject {
    @Published var list: [GetProfileModel] = []
    @Published var listImages: [GetUserProfileImagesModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetch_profile_EditProfile(uid: String) {
        isLoading = true
        ApiService.get_profile_EditProfile(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                   // print("Fetched profile data: \(String(describing: data))")  // Check if data is being fetched
                    self.list = data ?? []
                } else {
                    //print("Error message: \(String(describing: message))")  // Check if error is being returned
                    self.errorMessage = message
                }
            }
        }
    }


    func fetch_user_profile_images_EditProfile(uid: String) {
        isLoading = true
        ApiService.get_user_profile_images_EditProfile(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    print("Fetched images data: \(String(describing: data))")  // Check if data is being fetched
                    self.listImages = data ?? []
                } else {
                    print("Error message: \(String(describing: message))")  // Check if error is being returned
                    self.errorMessage = message
                }
            }
        }
    }
    
}
