//
//  CallLogger.swift
//  Enclosure
//
//  Centralized logger using os_log with PUBLIC visibility.
//  Logs are visible in Console.app even when app is killed and relaunched by iOS.
//  NSLog/print with string interpolation get redacted as <private> in Console.app.
//  os_log with %{public}s shows actual values.
//

import Foundation
import os.log

/// Centralized logger for VoIP/CallKit debugging.
/// All logs are PUBLIC — visible in Console.app even when Xcode is not attached.
///
/// Usage:
///   CallLogger.log("VoIP push received for room: \(roomId)")
///   CallLogger.log("CallKit answered", category: .callkit)
///   CallLogger.error("Audio activation failed: \(error)")
enum CallLogger {
    
    enum Category: String {
        case voip = "VoIP"
        case callkit = "CallKit"
        case audio = "Audio"
        case webrtc = "WebRTC"
        case session = "Session"
        case general = "General"
    }
    
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.enclosure"
    
    private static let loggers: [Category: OSLog] = [
        .voip: OSLog(subsystem: subsystem, category: "VoIP"),
        .callkit: OSLog(subsystem: subsystem, category: "CallKit"),
        .audio: OSLog(subsystem: subsystem, category: "Audio"),
        .webrtc: OSLog(subsystem: subsystem, category: "WebRTC"),
        .session: OSLog(subsystem: subsystem, category: "Session"),
        .general: OSLog(subsystem: subsystem, category: "General"),
    ]
    
    /// Log a PUBLIC message visible in Console.app even when app is killed
    static func log(_ message: String, category: Category = .general) {
        let logger = loggers[category] ?? OSLog.default
        // %{public}s ensures the string is NOT redacted in Console.app
        os_log("%{public}s", log: logger, type: .default, "📞 [\(category.rawValue)] \(message)")
    }
    
    /// Log an error (always visible, higher priority)
    static func error(_ message: String, category: Category = .general) {
        let logger = loggers[category] ?? OSLog.default
        os_log("%{public}s", log: logger, type: .error, "❌ [\(category.rawValue)] \(message)")
    }
    
    /// Log a success message
    static func success(_ message: String, category: Category = .general) {
        let logger = loggers[category] ?? OSLog.default
        os_log("%{public}s", log: logger, type: .default, "✅ [\(category.rawValue)] \(message)")
    }
    
    /// Log important info (higher visibility)
    static func info(_ message: String, category: Category = .general) {
        let logger = loggers[category] ?? OSLog.default
        os_log("%{public}s", log: logger, type: .info, "ℹ️ [\(category.rawValue)] \(message)")
    }
}
