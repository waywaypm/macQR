import SwiftUI
import AppKit
@preconcurrency import UserNotifications

// 实现UNUserNotificationCenterDelegate，允许应用在前台显示通知
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 应用在前台时显示通知，使用.banner替代已弃用的.alert
        completionHandler([.banner, .sound])
    }
}

@main
struct macQRApp: App {
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var qrHistoryManager = QRHistoryManager()
    
    // 保存通知代理的强引用
    private let notificationDelegate = NotificationDelegate()
    
    // 记录日志到文件 - 改为nonisolated，允许在非隔离上下文中调用
    nonisolated private func logToFile(_ message: String) {
        // 直接调用StatusBarController.shared.logMessage，它已经是nonisolated的
        StatusBarController.shared.logMessage(message)
    }
    
    // 记录日志 - 改为nonisolated，允许在非隔离上下文中调用
    nonisolated private func log(_ message: String) {
        // 只在开发环境下打印日志
        #if DEBUG
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"
        print("[DEBUG] \(logMessage)")
        logToFile(logMessage)
        #else
        // 生产环境下只写入日志文件，不打印到控制台
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"
        logToFile(logMessage)
        #endif
    }
    
  init() {
        // 安全地设置应用程序激活策略，.accessory表示只在状态栏显示，不显示在dock栏
        if let app = NSApp {
            app.setActivationPolicy(.accessory)
        }
        
        // 直接初始化状态栏控制器
        StatusBarController.shared.setup()
        
        // 设置PermissionManager的日志处理闭包 - 使用StatusBarController.shared直接调用
        PermissionManager.shared.setLogHandler { message in
            StatusBarController.shared.logMessage(message)
        }
        
        // 初始化通知功能 - 只在实际应用程序环境下执行
        // 检查是否是命令行调试环境 - 使用更可靠的检测方式
        let isCommandLineEnvironment = CommandLine.arguments.contains("--command-line") || Bundle.main.bundleURL.pathExtension != "app"
        log("是否是命令行环境: \(isCommandLineEnvironment)")
        
        // 检查是否强制启用通知功能
        let forceEnableNotifications = CommandLine.arguments.contains("--enable-notifications")
        log("是否强制启用通知功能: \(forceEnableNotifications)")
        
        // 只在非命令行环境下初始化通知功能
        guard !isCommandLineEnvironment else {
            log("命令行环境下，跳过通知功能初始化")
            return
        }
        
        // 初始化通知功能
        log("开始初始化通知功能")
        
        do {
            // 直接设置通知代理
            log("步骤1: 设置通知代理")
            UNUserNotificationCenter.current().delegate = notificationDelegate
            
            // 立即请求通知权限
            log("步骤2: 立即请求通知权限")
            let notificationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]
            log("请求的通知选项: \(notificationOptions)")
            
            // 请求通知权限
            UNUserNotificationCenter.current().requestAuthorization(options: notificationOptions) { granted, error in
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                
                if let error = error {
                    // 权限请求失败
                    let nsError = error as NSError
                    let errorMessage = "[\(timestamp)] 权限请求失败: 错误=\(error), 代码=\(nsError.code), 描述=\(nsError.localizedDescription)"
                    print("[DEBUG] \(errorMessage)")
                    StatusBarController.shared.logMessage(errorMessage)
                } else {
                    // 权限请求结果
                    let successMessage = "[\(timestamp)] 权限请求完成: 结果=\(granted)"
                    print("[DEBUG] \(successMessage)")
                    StatusBarController.shared.logMessage(successMessage)
                    
                    // 记录权限状态
                    let permissionStatus = granted ? "已获得" : "已拒绝"
                    let statusMessage = "[\(timestamp)] 通知权限状态: \(permissionStatus)"
                    print("[DEBUG] \(statusMessage)")
                    StatusBarController.shared.logMessage(statusMessage)
                    
                    // 检查当前通知设置
                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                        
                        // 记录详细的通知设置
                        let settingsInfo = "授权状态=\(settings.authorizationStatus), 通知中心设置=\(settings.notificationCenterSetting), 声音设置=\(settings.soundSetting), 徽章设置=\(settings.badgeSetting), 锁屏设置=\(settings.lockScreenSetting)"
                        let settingsMessage = "[\(timestamp)] 当前通知设置: \(settingsInfo)"
                        print("[DEBUG] \(settingsMessage)")
                        StatusBarController.shared.logMessage(settingsMessage)
                    }
                }
            }
            
            // 初始化通知功能完成
        } catch {
            log("初始化通知功能失败: \(error)")
        }
    }
    
    var body: some Scene {
        // 配置应用不自动创建窗口
        // 移除所有WindowGroup，只保留应用代理配置
        // 所有窗口将通过StatusBarController手动创建
    }
    
    // 防止应用在所有窗口关闭时退出
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
}

// 自定义应用代理，控制应用退出行为和窗口生命周期
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 返回false表示应用在所有窗口关闭时不退出
        let message = "应用窗口全部关闭，检查是否应该退出：返回false（不退出）"
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
        return false
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let message = "应用启动完成，当前窗口数量：\(NSApp.windows.count)"
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
        
        // 记录应用启动时的窗口信息
        for (index, window) in NSApp.windows.enumerated() {
            let windowInfo = "应用启动时窗口\(index): 标题=\"\(window.title)\", 可见=\(window.isVisible), 关键窗口=\(window.isKeyWindow), 主窗口=\(window.isMainWindow), 大小=\(window.frame.size)"
            print("[DEBUG] \(windowInfo)")
            StatusBarController.shared.logMessage(windowInfo)
        }
        
        // 检查是否是首次启动
        let userDefaults = UserDefaults.standard
        let isFirstLaunch = !userDefaults.bool(forKey: "hasLaunchedBefore")
        
        // 记录首次启动状态
        print("[DEBUG] 首次启动检查: \(isFirstLaunch)")
        StatusBarController.shared.logMessage("首次启动检查: \(isFirstLaunch)")
        
        // 如果是首次启动，标记为已启动
        if isFirstLaunch {
            userDefaults.set(true, forKey: "hasLaunchedBefore")
            print("[DEBUG] 标记应用为已启动")
            StatusBarController.shared.logMessage("标记应用为已启动")
        }
        
        // 检查并请求屏幕录制权限
        let permissionManager = PermissionManager.shared
        permissionManager.requestScreenRecordingPermission()
        
        // 延迟检查权限状态，确保权限请求已完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 检查权限状态，如果未授权，显示权限引导窗口
            if !permissionManager.hasScreenRecordingPermission {
                print("[DEBUG] 未授权，显示权限引导窗口")
                StatusBarController.shared.logMessage("未授权，显示权限引导窗口")
                
                // 手动创建并显示权限引导窗口
                let permissionWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
                    styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )
                permissionWindow.center()
                permissionWindow.title = "权限引导"
                permissionWindow.isReleasedWhenClosed = false
                
                // 设置窗口内容视图为PermissionView
                let permissionView = PermissionView().environmentObject(permissionManager)
                permissionWindow.contentView = NSHostingView(rootView: permissionView)
                
                // 显示窗口
                permissionWindow.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    func applicationWillBecomeActive(_ notification: Notification) {
        let message = "应用即将激活，当前窗口数量：\(NSApp.windows.count)"
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
        
        // 打印当前所有窗口信息
        for (index, window) in NSApp.windows.enumerated() {
            let windowInfo = "窗口\(index): 标题=\"\(window.title)\", 可见=\(window.isVisible), 关键窗口=\(window.isKeyWindow), 主窗口=\(window.isMainWindow), 大小=\(window.frame.size)"
            print("[DEBUG] \(windowInfo)")
            StatusBarController.shared.logMessage(windowInfo)
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        let message = "应用已激活，当前窗口数量：\(NSApp.windows.count)"
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        let message = "应用即将失去激活，当前窗口数量：\(NSApp.windows.count)"
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        let message = "应用已失去激活，当前窗口数量：\(NSApp.windows.count)"
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
    }
    
    func application(_ sender: NSApplication, didCreate window: NSWindow) {
        let message = "应用创建了新窗口：标题=\"\(window.title)\", 大小=\(window.frame.size), isMainWindow=\(window.isMainWindow)"
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
    }
    
    func application(_ sender: NSApplication, willUseFullScreenPresentationOptions options: NSApplication.PresentationOptions, for window: NSWindow) -> NSApplication.PresentationOptions {
        let message = "窗口即将进入全屏：标题=\"\(window.title)\""
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
        return options
    }
    
    // 处理点击dock栏图标的事件
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let message = "点击dock栏图标，当前可见窗口：\(flag)，当前窗口数量：\(NSApp.windows.count)"
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
        
        // 如果没有可见窗口，创建一个新窗口
        if !flag {
            let message = "点击dock栏图标，没有可见窗口，请求创建新窗口"
            print("[DEBUG] \(message)")
            StatusBarController.shared.logMessage(message)
        }
        
        // 返回true表示应用将处理reopen事件
        return true
    }
    
    // 监听窗口创建事件
    func application(_ sender: NSApplication, didChangeScreenParameters notification: Notification) {
        let message = "屏幕参数变化，当前窗口数量：\(NSApp.windows.count)"
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
    }
    
    // 监听窗口关闭事件
    func application(_ sender: NSApplication, willTerminate notification: Notification) {
        let message = "应用即将终止，当前窗口数量：\(NSApp.windows.count)"
        print("[DEBUG] \(message)")
        StatusBarController.shared.logMessage(message)
    }
}