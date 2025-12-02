import SwiftUI
import AppKit
import UserNotifications

// 移除类级别的@MainActor，改为在需要的方法上使用@MainActor标记
class PermissionManager: ObservableObject, @unchecked Sendable {
    // 单例实例
    static let shared = PermissionManager()
    
    @Published var hasScreenRecordingPermission: Bool = false
    @Published var hasNotificationPermission: Bool = false
    
    // 日志记录闭包，用于将日志写入文件
    private var logHandler: ((String) -> Void)?
    
    // 设置日志处理闭包
    func setLogHandler(_ handler: @escaping (String) -> Void) {
        self.logHandler = handler
    }
    
    // 记录日志
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"
        print("[DEBUG] \(logMessage)")
        logHandler?(logMessage)
    }
    
    // 私有初始化方法，防止外部创建实例
    private init() {
        log("PermissionManager初始化")
        checkScreenRecordingPermission()
        // 延迟检查通知权限，确保应用程序环境已准备好
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkNotificationPermission()
        }
        log("PermissionManager初始化完成")
    }
    
    func checkScreenRecordingPermission() {
        log("开始检查屏幕录制权限")
        // 使用 CGPreflightScreenCaptureAccess 检查屏幕录制权限
        let hasPermission = CGPreflightScreenCaptureAccess()
        hasScreenRecordingPermission = hasPermission
        log("屏幕录制权限检查结果: \(hasPermission)")
    }
    
    func requestScreenRecordingPermission() {
        log("开始请求屏幕录制权限")
        // 使用 CGRequestScreenCaptureAccess 请求屏幕录制权限
        let granted = CGRequestScreenCaptureAccess()
        hasScreenRecordingPermission = granted
        log("屏幕录制权限请求结果: \(granted)")
    }
    
    func checkNotificationPermission() {
        log("开始检查通知权限")
        
        // 检查是否是命令行调试环境
        let isCommandLineEnvironment = Bundle.main.bundleURL.pathExtension != "app"
        log("是否是命令行环境: \(isCommandLineEnvironment)")
        
        // 只在非命令行环境下检查通知权限
        if !isCommandLineEnvironment {
            // 检查应用程序bundle是否有效，避免在命令行环境下崩溃
            let bundleURL = Bundle.main.bundleURL
            let bundleExists = FileManager.default.fileExists(atPath: bundleURL.path)
            let isAppBundle = bundleURL.pathExtension == "app"
            
            log("应用程序bundle存在: \(bundleExists), 路径: \(bundleURL.path), 是否是.app包: \(isAppBundle)")
            
            if bundleExists && isAppBundle {
                // 检查通知权限
                UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                    guard let self = self else { return }
                    
                    // 更新权限状态
                    let isAuthorized = settings.authorizationStatus == .authorized
                    let authStatus = settings.authorizationStatus
                    let notificationCenterSetting = settings.notificationCenterSetting
                    let soundSetting = settings.soundSetting
                    let badgeSetting = settings.badgeSetting
                    let lockScreenSetting = settings.lockScreenSetting
                    
                    DispatchQueue.main.async {
                        self.hasNotificationPermission = isAuthorized
                        self.log("通知权限检查结果: \(isAuthorized)")
                        self.log("详细通知设置: 授权状态=\(authStatus), 通知中心设置=\(notificationCenterSetting), 声音设置=\(soundSetting), 徽章设置=\(badgeSetting), 锁屏设置=\(lockScreenSetting)")
                    }
                }
            } else {
                log("应用程序bundle无效或不是.app包，跳过通知权限检查")
                DispatchQueue.main.async {
                    self.hasNotificationPermission = false
                }
            }
        } else {
            log("命令行环境下，跳过通知权限检查")
            DispatchQueue.main.async {
                self.hasNotificationPermission = false
            }
        }
    }
    
    func requestNotificationPermission() {
        log("开始请求通知权限")
        
        // 检查是否是命令行调试环境
        let isCommandLineEnvironment = Bundle.main.bundleURL.pathExtension != "app"
        log("是否是命令行环境: \(isCommandLineEnvironment)")
        
        // 只在非命令行环境下请求通知权限
        if !isCommandLineEnvironment {
            // 检查应用程序bundle是否有效，避免在命令行环境下崩溃
            let bundleURL = Bundle.main.bundleURL
            let bundleExists = FileManager.default.fileExists(atPath: bundleURL.path)
            let isAppBundle = bundleURL.pathExtension == "app"
            
            log("应用程序bundle存在: \(bundleExists), 路径: \(bundleURL.path), 是否是.app包: \(isAppBundle)")
            
            if bundleExists && isAppBundle {
                // 请求通知权限
                let notificationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]
                log("请求的通知权限选项: \(notificationOptions)")
                
                UNUserNotificationCenter.current().requestAuthorization(options: notificationOptions) { [weak self] granted, error in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        if let error = error {
                            let nsError = error as NSError
                            self.log("请求通知权限失败: 错误=\(error), 代码=\(nsError.code), 描述=\(nsError.localizedDescription)")
                        } else {
                            self.log("请求通知权限成功: 结果=\(granted)")
                            self.hasNotificationPermission = granted
                        }
                    }
                }
            } else {
                log("应用程序bundle无效或不是.app包，跳过通知权限请求")
                DispatchQueue.main.async {
                    self.hasNotificationPermission = false
                }
            }
        } else {
            log("命令行环境下，跳过通知权限请求")
            DispatchQueue.main.async {
                self.hasNotificationPermission = false
            }
        }
    }
    
    func openSystemSettings() {
        log("打开系统屏幕录制权限设置")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            if NSWorkspace.shared.open(url) {
                log("成功打开系统设置")
                // 自动触发一次录屏权限申请，确保应用出现在系统权限列表中
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.requestScreenRecordingPermission()
                }
            } else {
                log("打开系统设置失败")
            }
        } else {
            log("无效的系统设置URL")
        }
    }
    
    func openNotificationSettings() {
        log("打开系统通知设置")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            if NSWorkspace.shared.open(url) {
                log("成功打开系统通知设置")
            } else {
                log("打开系统通知设置失败")
            }
        } else {
            log("无效的系统通知设置URL")
        }
    }
}