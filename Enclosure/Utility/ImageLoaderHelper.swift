//
//  ImageLoaderHelper.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI

struct ImageLoaderHelper {
    static func logImageLoad(_ imageName: String, success: Bool) {
        if success {
            print("✅ [ImageLoader] Icon loaded successfully: \(imageName)")
        } else {
            print("❌ [ImageLoader] Icon MISSING or FAILED to load: \(imageName)")
        }
    }
    
    static func checkImageExists(_ imageName: String) -> Bool {
        if UIImage(named: imageName) != nil {
            logImageLoad(imageName, success: true)
            return true
        } else {
            logImageLoad(imageName, success: false)
            return false
        }
    }
}

extension View {
    func logImageLoad(_ imageName: String) -> some View {
        self.onAppear {
            ImageLoaderHelper.checkImageExists(imageName)
        }
    }
}

