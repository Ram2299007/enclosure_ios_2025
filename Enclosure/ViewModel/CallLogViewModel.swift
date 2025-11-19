import Foundation
import Combine

private enum CallLogCacheReason: CustomStringConvertible, Equatable {
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

final class CallLogViewModel: ObservableObject {
    enum LogType {
        case voice
        case video
    }
    
    @Published var sections: [CallLogSection] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasCachedSections: Bool = false
    
    private var hasLoadedOnce = false
    private let logType: LogType
    private let cacheType: CallLogCacheType
    private let cacheManager = CallCacheManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    init(logType: LogType = .voice) {
        self.logType = logType
        self.cacheType = logType == .voice ? .voice : .video
    }
    
    func fetchCallLogs(uid: String, force: Bool = false) {
        guard !uid.isEmpty else { return }
        if isLoading { return }
        if !force && hasLoadedOnce && !sections.isEmpty { return }
        
        isLoading = true
        errorMessage = nil
        
        loadCachedCallLogs(reason: .prefetch, shouldStopLoading: false)
        
        guard networkMonitor.isConnected else {
            print("📞 [CallLogViewModel] No internet connection, loading cached call logs (\(logType))")
            loadCachedCallLogs(reason: .offline)
            return
        }
        
        let completion: (Bool, String, [CallLogSection]?) -> Void = { [weak self] success, message, data in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                self.hasLoadedOnce = true
                
                if success {
                    let sanitized = self.filterBlockedEntries(from: data ?? [])
                    self.sections = sanitized
                    self.hasCachedSections = !sanitized.isEmpty
                    
                    if sanitized.isEmpty {
                        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        let lowercasedMessage = trimmedMessage.lowercased()
                        let shouldShowMessage = !trimmedMessage.isEmpty &&
                        !(lowercasedMessage == "success" || lowercasedMessage == "message" || lowercasedMessage == "ok")
                        self.errorMessage = shouldShowMessage ? trimmedMessage : nil
                    } else {
                        self.errorMessage = nil
                    }
                    
                    self.cacheManager.cacheCallLogs(sanitized, type: self.cacheType)
                } else {
                    self.errorMessage = message
                    if self.sections.isEmpty {
                        self.loadCachedCallLogs(reason: .error(message))
                    }
                }
            }
        }
        
        switch logType {
        case .voice:
            ApiService.get_voice_call_log(uid: uid, completion: completion)
        case .video:
            ApiService.get_video_call_log(uid: uid, completion: completion)
        }
    }
    
    func refresh(uid: String) {
        sections.removeAll()
        hasLoadedOnce = false
        fetchCallLogs(uid: uid, force: true)
    }
    
    private func filterBlockedEntries(from sections: [CallLogSection]) -> [CallLogSection] {
        sections.compactMap { section in
            let filteredUsers = section.userInfo.filter { !$0.block }
            guard !filteredUsers.isEmpty else { return nil }
            var updatedSection = section
            updatedSection.userInfo = filteredUsers
            return updatedSection
        }
    }
    
    private func loadCachedCallLogs(reason: CallLogCacheReason, shouldStopLoading: Bool = true) {
        cacheManager.fetchCallLogs(type: cacheType) { [weak self] cachedSections in
            guard let self = self else { return }
            if cachedSections.isEmpty && reason == .prefetch {
                // Do not override existing data with empty cache during prefetch.
            } else {
                self.sections = cachedSections
            }
            self.hasCachedSections = !cachedSections.isEmpty
            if shouldStopLoading {
                self.isLoading = false
            }
            
            switch reason {
            case .offline:
                self.errorMessage = cachedSections.isEmpty ? "You are offline. No cached call logs available." : nil
            case .prefetch:
                break
            case .error(let message):
                if cachedSections.isEmpty {
                    self.errorMessage = message?.isEmpty == false ? message : "Unable to load call logs."
                } else {
                    self.errorMessage = nil
                }
            }
            
            print("📞 [CallLogViewModel] Loaded \(cachedSections.count) cached logs for reason: \(reason) (\(self.logType))")
        }
    }
}

