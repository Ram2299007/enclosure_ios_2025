import Foundation
import Combine

final class CallLogViewModel: ObservableObject {
    enum LogType {
        case voice
        case video
    }
    
    @Published var sections: [CallLogSection] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var hasLoadedOnce = false
    private let logType: LogType
    
    init(logType: LogType = .voice) {
        self.logType = logType
    }
    
    func fetchCallLogs(uid: String, force: Bool = false) {
        guard !uid.isEmpty else { return }
        if isLoading { return }
        if !force && hasLoadedOnce && !sections.isEmpty { return }
        
        isLoading = true
        errorMessage = nil
        
        let completion: (Bool, String, [CallLogSection]?) -> Void = { [weak self] success, message, data in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                self.hasLoadedOnce = true
                
                if success {
                    let sanitized = self.filterBlockedEntries(from: data ?? [])
                    self.sections = sanitized
                    
                    if self.sections.isEmpty {
                        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        let lowercasedMessage = trimmedMessage.lowercased()
                        let shouldShowMessage = !trimmedMessage.isEmpty &&
                            !(lowercasedMessage == "success" || lowercasedMessage == "message" || lowercasedMessage == "ok")
                        self.errorMessage = shouldShowMessage ? trimmedMessage : nil
                    } else {
                        self.errorMessage = nil
                    }
                } else {
                    self.sections = []
                    self.errorMessage = message 
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
}

