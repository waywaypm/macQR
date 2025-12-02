import SwiftUI
import AppKit

struct PermissionView: View {
    @EnvironmentObject var permissionManager: PermissionManager
    
    // 添加权限检查结果状态
    @State private var checkResult: String?
    @State private var checkResultColor: Color = .primary
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.screen")
                .font(.system(size: 64))
                .foregroundColor(.yellow)
            
            Text("需要屏幕录制权限")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("macQR需要访问您的屏幕来识别二维码。请在系统设置中开启屏幕录制权限。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("开启步骤：")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("1. 点击下方按钮打开系统设置")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("2. 在左侧列表中选择\"屏幕录制\"")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("3. 找到\"macQR\"并勾选旁边的复选框")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("4. 关闭设置窗口，返回macQR")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
            .frame(maxWidth: 400)
            
            // 显示权限检查结果
            if let result = checkResult {
                HStack {
                    Image(systemName: permissionManager.hasScreenRecordingPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissionManager.hasScreenRecordingPermission ? .green : .red)
                    Text(result)
                        .foregroundColor(checkResultColor)
                        .font(.body)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(checkResultColor.opacity(0.1))
                )
                .frame(maxWidth: 400)
            }
            
            HStack(spacing: 15) {
                Button(action: {
                    permissionManager.openSystemSettings()
                    // 记录日志
                    StatusBarController.shared.logMessage("用户点击了'打开系统设置'按钮")
                }) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("打开系统设置")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    // 记录日志
                    StatusBarController.shared.logMessage("用户点击了'已开启，继续'按钮")
                    
                    // 检查权限
                    permissionManager.checkScreenRecordingPermission()
                    
                    // 显示检查结果
                    if permissionManager.hasScreenRecordingPermission {
                        checkResult = "权限已开启，可以继续使用macQR"
                        checkResultColor = .green
                        // 记录日志
                        StatusBarController.shared.logMessage("屏幕录制权限检查通过")
                    } else {
                        checkResult = "权限未开启，请按照步骤开启权限"
                        checkResultColor = .red
                        // 记录日志
                        StatusBarController.shared.logMessage("屏幕录制权限检查未通过")
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("已开启，继续")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 400)
    }
}