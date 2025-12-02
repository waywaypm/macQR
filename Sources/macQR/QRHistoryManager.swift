import SwiftUI
import Foundation

struct QRCodeHistoryItem: Identifiable, Codable {
    var id = UUID()
    let content: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, content, timestamp
    }
}

class QRHistoryManager: ObservableObject {
    @Published var history: [QRCodeHistoryItem] = []
    
    private let historyKey = "macQRHistory"
    
    init() {
        loadHistory()
    }
    
    func addItem(content: String) {
        let item = QRCodeHistoryItem(content: content, timestamp: Date())
        history.insert(item, at: 0) // 最新的记录放在最前面
        
        // 限制历史记录数量
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        
        saveHistory()
    }
    
    func removeItem(id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([QRCodeHistoryItem].self, from: data) {
                history = decoded
            }
        }
    }
}