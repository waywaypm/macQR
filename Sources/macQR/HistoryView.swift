import SwiftUI
import AppKit

struct HistoryView: View {
    @EnvironmentObject var qrHistoryManager: QRHistoryManager
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("历史记录")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: qrHistoryManager.clearHistory) {
                    Text("清空")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // 历史记录列表
            if qrHistoryManager.history.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无历史记录")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(minWidth: 300, minHeight: 200)
            } else {
                List(qrHistoryManager.history) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.content)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            Text(formatDate(item.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 10) {
                            Button(action: { copyToClipboard(item.content) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            Button(action: { qrHistoryManager.removeItem(id: item.id) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func copyToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
}