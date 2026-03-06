import Foundation

struct CallHistoryFormatter {
    private static let timeWithSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm:ss a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private static let timeWithoutSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private static let timeOutputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private static let combinedWithSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd hh:mm:ss a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private static let combinedWithoutSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd hh:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static func formattedTime(from raw: String) -> String {
        guard let date = parseTime(raw) else { return raw }
        return timeOutputFormatter.string(from: date)
    }
    
    static func durationBetween(start: String, end: String) -> String? {
        let trimmedStart = start.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnd = end.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedStart.isEmpty,
              !trimmedEnd.isEmpty,
              let startDate = parseTime(trimmedStart),
              let endDate = parseTime(trimmedEnd) else {
            return nil
        }
        
        let diff = endDate.timeIntervalSince(startDate)
        guard diff > 0 else { return nil }
        
        let totalMinutes = Int(diff / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    static func combinedDate(date: String, time: String) -> Date? {
        let trimmedDate = date.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTime = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDate.isEmpty, !trimmedTime.isEmpty else { return nil }
        
        let raw = "\(trimmedDate) \(trimmedTime)"
        
        if let parsed = combinedWithSeconds.date(from: raw) {
            return parsed
        }
        
        return combinedWithoutSeconds.date(from: raw)
    }
    
    private static func parseTime(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        if let date = timeWithSeconds.date(from: trimmed) {
            return date
        }
        
        return timeWithoutSeconds.date(from: trimmed)
    }
}

