import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var qrHistoryManager: QRHistoryManager
    
    @State private var qrCodeContent: [String] = []
    @State private var isScanning: Bool = false
    @State private var showCopySuccess: Bool = false
    @State private var copiedContent: String?
    
    // 主题色彩方案 - 符合Apple设计规范的系统颜色
    private let primaryColor = Color.accentColor // 使用系统强调色
    private let secondaryColor = Color.secondary // 系统辅助色
    private let successColor = Color.green // 系统绿色
    private let backgroundColor = Color(.windowBackgroundColor) // 系统窗口背景色
    private let cardColor = Color(.controlBackgroundColor) // 系统控件背景色
    private let borderColor = Color(.separatorColor) // 系统分隔线颜色
    
    // 动画配置
    private let animationDuration = 0.3
    private let animationEasing = Animation.easeInOut(duration: 0.3)
    
    var body: some View {
        VStack(spacing: 24) {
            // 应用标题和描述
            VStack(spacing: 8) {
                Text("macQR")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .transition(.opacity)
                
                Text("智能二维码识别工具")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryColor)
                    .transition(.opacity)
            }
            .padding(.top, 8)
            
            Spacer(minLength: 16)
            
            // 主要内容区域
            ZStack {
                // 卡片背景 - 增强视觉层次感
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardColor)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4) // 增强阴影效果
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor.opacity(0.3), lineWidth: 0.5) // 添加细边框
                    )
                    .frame(maxWidth: 700, maxHeight: 500)
                    .transition(.opacity.combined(with: .scale))
                
                VStack(spacing: 24) {
                    if isScanning {
                        // 加载状态 - 增强动画效果
                        VStack(spacing: 24) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(primaryColor)
                                .padding()
                                .transition(.scale)
                            
                            Text("正在识别二维码...")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryColor)
                                .transition(.opacity)
                            
                            // 添加扫描动画效果
                            ScanAnimationView()
                                .frame(width: 120, height: 120)
                                .transition(.opacity)
                        }
                        .padding(60)
                        .opacity(1)
                    } else if !qrCodeContent.isEmpty {
                        // 识别结果展示 - 增强视觉层次和动画效果
                        VStack(spacing: 24) {
                            // 结果标题 - 增强视觉层次
                            HStack {
                                Text("识别结果")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(qrCodeContent.count) 个二维码")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(primaryColor)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(primaryColor.opacity(0.1))
                                    )
                                    .transition(.scale)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .slide))
                            
                            // 结果列表 - 增强视觉层次和动画效果
                            ScrollView {
                                VStack(spacing: 16) {
                                    ForEach(qrCodeContent.indices, id: \.self) { index in
                                        let content = qrCodeContent[index]
                                        ResultCardView(content: content, index: index, onCopy: copyToClipboard)
                                            .transition(.opacity.combined(with: .slide))
                                            .animation(animationEasing.delay(Double(index) * 0.1), value: qrCodeContent)
                                    }
                                }
                                .padding(.bottom, 12)
                            }
                            .frame(maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .transition(.opacity)
                            
                            // 复制成功提示 - 增强动画效果
                            if showCopySuccess, let content = copiedContent {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(successColor)
                                        .transition(.scale)
                                    
                                    Text("已复制到剪贴板")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(successColor)
                                        .transition(.opacity)
                                    
                                    Text(content.count > 20 ? String(content.prefix(20)) + "..." : content)
                                        .font(.system(size: 14, weight: .regular, design: .rounded))
                                        .foregroundColor(secondaryColor)
                                        .lineLimit(1)
                                        .transition(.opacity)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(successColor.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(successColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .transition(.opacity.combined(with: .slide))
                                .animation(animationEasing, value: showCopySuccess)
                            }
                        }
                        .padding(32)
                        .transition(.opacity)
                    } else {
                        // 空状态 - 增强视觉效果和动画
                        VStack(spacing: 32) {
                            // 图标 - 增强动画效果
                            Image(systemName: "qrcode.viewfinder")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(primaryColor.opacity(0.6))
                                .shadow(color: primaryColor.opacity(0.2), radius: 24, x: 0, y: 8) // 增强阴影效果
                                .transition(.scale.combined(with: .opacity))
                                .animation(animationEasing.repeatForever(autoreverses: true).speed(0.5), value: UUID())
                            
                            // 文本内容 - 增强排版层次
                            VStack(spacing: 10) {
                                Text("开始识别二维码")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .transition(.opacity)
                                
                                Text("点击下方按钮，macQR将扫描屏幕上所有可见的二维码")
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(secondaryColor)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(5)
                                    .frame(maxWidth: 320)
                                    .transition(.opacity)
                            }
                            .transition(.opacity)
                        }
                        .padding(64)
                        .transition(.opacity)
                    }
                }
            }
            .animation(animationEasing, value: isScanning)
            .animation(animationEasing, value: qrCodeContent)
            
            Spacer(minLength: 24)
            
            // 操作按钮 - 增强交互反馈
            VStack(spacing: 16) {
                // 开始识别按钮 - 增强动画效果和交互反馈
                Button(action: startScanning) {
                    HStack(spacing: 12) {
                        Image(systemName: isScanning ? "hourglass" : "qrcode.viewfinder")
                            .font(.system(size: 18, weight: .medium))
                        
                        Text(isScanning ? "识别中..." : "开始识别")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryColor)
                .controlSize(.large)
                .disabled(isScanning)
                .overlay(
                    // 添加加载状态的进度条效果
                    Group {
                        if isScanning {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(primaryColor.opacity(0.5), lineWidth: 2)
                                .scaleEffect(x: 1.02, y: 1.05, anchor: .center)
                                .animation(Animation.easeInOut(duration: 1).repeatForever(), value: isScanning)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .scale))
                .animation(animationEasing, value: isScanning)
                
                // 权限状态信息 - 增强视觉层次
                VStack(spacing: 10) {
                    // 屏幕录制权限
                    PermissionStatusView(
                        title: "屏幕录制权限",
                        isGranted: permissionManager.hasScreenRecordingPermission,
                        onRequest: permissionManager.openSystemSettings
                    )
                    
                    // 通知权限
                    PermissionStatusView(
                        title: "通知权限",
                        isGranted: permissionManager.hasNotificationPermission,
                        onRequest: permissionManager.openNotificationSettings
                    )
                }
                .frame(maxWidth: 320)
                .transition(.opacity)
            }
        }
        .padding(40)
        .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
        .background(backgroundColor)
        .animation(animationEasing, value: qrCodeContent)
        .animation(animationEasing, value: isScanning)
    }
    
    private func startScanning() {
        Task {
            isScanning = true
            defer { isScanning = false }
            
            // 获取所有识别结果
            let results = await StatusBarController.shared.scanScreensForAllResults()
            
            if !results.isEmpty {
                qrCodeContent = results
            } else {
                qrCodeContent = []
            }
        }
    }
    
    private func copyToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        copiedContent = content
        showCopySuccess = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(animationEasing) {
                showCopySuccess = false
            }
        }
    }
}

// MARK: - Helper Views

/// 扫描动画视图
struct ScanAnimationView: View {
    @State private var scanOffset: CGFloat = 0
    
    private let animationDuration = 2.0
    private let animationEasing = Animation.linear(duration: 2.0).repeatForever()
    
    var body: some View {
        ZStack {
            // 二维码外框
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundColor(Color.secondary.opacity(0.3))
            
            // 扫描线动画
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(0.6))
                .frame(width: 80, height: 2)
                .offset(y: scanOffset)
                .animation(animationEasing, value: scanOffset)
        }
        .onAppear {
            // 启动扫描动画
            scanOffset = -40
            withAnimation(animationEasing) {
                scanOffset = 40
            }
        }
    }
}

/// 结果卡片视图
struct ResultCardView: View {
    let content: String
    let index: Int
    let onCopy: (String) -> Void
    
    private let primaryColor = Color.accentColor
    private let secondaryColor = Color.secondary
    private let backgroundColor = Color(.controlBackgroundColor)
    private let borderColor = Color(.separatorColor)
    
    var body: some View {
        HStack(spacing: 16) {
            // 序号标记
            Circle()
                .fill(primaryColor.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(primaryColor)
                )
                .transition(.scale)
            
            // 识别结果内容
            Text(content)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor.opacity(0.5), lineWidth: 0.5)
                        )
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .slide))
            
            // 复制按钮 - 增强交互反馈
            Button(action: { onCopy(content) }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(primaryColor)
            .controlSize(.regular)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .transition(.scale)
        }
        .frame(maxWidth: 600, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

/// 权限状态视图
struct PermissionStatusView: View {
    let title: String
    let isGranted: Bool
    let onRequest: () -> Void
    
    private let successColor = Color.green
    private let primaryColor = Color.accentColor
    private let secondaryColor = Color.secondary
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(title):")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(secondaryColor)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            if isGranted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(successColor)
                        .font(.system(size: 14))
                    Text("已授权")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(successColor)
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                Button(action: onRequest) {
                    Text("去授权")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(primaryColor)
                        .underline()
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(Animation.easeInOut(duration: 0.2), value: isGranted)
    }
}