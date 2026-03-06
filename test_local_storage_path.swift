#!/usr/bin/env swift

// Quick test script to find the full path
// Run this in Terminal: swift test_local_storage_path.swift

import Foundation

let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)

print("\n")
print("═══════════════════════════════════════════════════════════")
print("📱 FULL PATH TO IMAGES DIRECTORY")
print("═══════════════════════════════════════════════════════════")
print("")
print("📍 \(imagesDir.path)")
print("")
print("═══════════════════════════════════════════════════════════")

// Extract components
let pathComponents = imagesDir.path.components(separatedBy: "/")

if let deviceIdIndex = pathComponents.firstIndex(of: "Devices"),
   deviceIdIndex + 1 < pathComponents.count {
    let deviceId = pathComponents[deviceIdIndex + 1]
    print("📱 DEVICE_ID: \(deviceId)")
}

if let appIdIndex = pathComponents.firstIndex(of: "Application"),
   appIdIndex + 1 < pathComponents.count {
    let appId = pathComponents[appIdIndex + 1]
    print("📱 APP_ID: \(appId)")
}

print("")
print("💡 TO ACCESS IN FINDER:")
print("   1. Press Cmd + Shift + G")
print("   2. Paste: \(imagesDir.path)")
print("   3. Press Enter")
print("═══════════════════════════════════════════════════════════")
print("")

