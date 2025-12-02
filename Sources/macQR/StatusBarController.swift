import SwiftUI
import AppKit
import Vision
@preconcurrency import UserNotifications

// 移除类级别的@MainActor，改为在需要的方法上使用@MainActor标记
class StatusBarController: ObservableObject, @unchecked Sendable {
    // 单例实例
    static let shared = StatusBarController()
    
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    private let permissionManager: PermissionManager
    private let qrHistoryManager: QRHistoryManager
    private let qrCodeScanner: QRCodeScanner
    
    // 存储最新的识别结果
    private var latestQRResult: (content: String, timestamp: Date)?
    
    // 识别结果菜单项
    private var resultMenuItem: NSMenuItem?
    
    // 私有初始化方法
    private init() {
        // 初始化管理器
        self.permissionManager = PermissionManager.shared
        self.qrHistoryManager = QRHistoryManager()
        self.qrCodeScanner = QRCodeScanner()
        
        // 设置日志处理闭包，将PermissionManager的日志记录到文件
        PermissionManager.shared.setLogHandler { message in
            StatusBarController.shared.logMessage(message)
        }
    }
    
    // MARK: - Setup Methods
    @MainActor
    func setup() {
        setupStatusBar()
        setupMenu()
        
        // 写入一条测试日志
        logMessage("应用启动")
    }
    
    @MainActor
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // 使用系统提供的美观二维码图标
            if let image = NSImage(systemSymbolName: "qrcode", accessibilityDescription: "macQR") {
                button.image = image
            }
            button.action = #selector(showMenu)
            button.target = self
        }
    }
    
    @MainActor
    private func setupMenu() {
        menu = NSMenu()
        
        // 识别屏幕二维码菜单项
        let scanMenuItem = NSMenuItem(title: "识别屏幕二维码", action: #selector(scanQRCode), keyEquivalent: "")
        scanMenuItem.target = self
        menu?.addItem(scanMenuItem)
        
        // 识别结果菜单项
        resultMenuItem = NSMenuItem(title: "复制最新: 无", action: #selector(copyLatestQRResult), keyEquivalent: "")
        resultMenuItem?.target = self
        resultMenuItem?.isEnabled = false
        menu?.addItem(resultMenuItem!)
        
        // 查看历史记录菜单项
        let historyMenuItem = NSMenuItem(title: "查看历史记录", action: #selector(showHistory), keyEquivalent: "")
        historyMenuItem.target = self
        menu?.addItem(historyMenuItem)
        
        // 分隔线
        menu?.addItem(NSMenuItem.separator())
        
        // 打开通知设置菜单项
        let notificationSettingsMenuItem = NSMenuItem(title: "打开通知设置", action: #selector(openNotificationSettings), keyEquivalent: "")
        notificationSettingsMenuItem.target = self
        menu?.addItem(notificationSettingsMenuItem)
        
        // 打开主窗口菜单项
        let openWindowMenuItem = NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: "")
        openWindowMenuItem.target = self
        menu?.addItem(openWindowMenuItem)
        
        // 退出应用菜单项
        let quitMenuItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu?.addItem(quitMenuItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Menu Actions
    @MainActor
    @objc private func openNotificationSettings() {
        // 打开系统通知设置
        permissionManager.openNotificationSettings()
    }
    
    // 复制最新识别结果到剪贴板
    @MainActor
    @objc private func copyLatestQRResult() {
        if let result = latestQRResult {
            copyToClipboard(result.content)
            showNotification(title: "复制成功", subtitle: "二维码内容已复制到剪贴板")
        }
    }
    
    // 更新识别结果菜单项
    @MainActor
    private func updateResultMenuItem() {
        if let resultMenuItem = resultMenuItem {
            if let result = latestQRResult {
                // 格式化时间为小时:分钟格式
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "HH:mm"
                let timeString = dateFormatter.string(from: result.timestamp)
                
                resultMenuItem.title = "复制最新（\(timeString)）: \(result.content)"
                resultMenuItem.isEnabled = true
            } else {
                resultMenuItem.title = "复制最新: 无"
                resultMenuItem.isEnabled = false
            }
        }
    }
    
    @MainActor
    @objc private func showMenu() {
        statusItem?.menu?.popUp(positioning: nil, at: NSPoint.zero, in: statusItem?.button)
    }
    
    @MainActor
    @objc private func scanQRCode() {
        // 使用Task执行异步操作
        Task {
            // 直接请求权限，确保能够扫描屏幕
            permissionManager.requestScreenRecordingPermission()
            // 扫描所有屏幕
            let result = await self.scanAllScreens()
            print("扫描结果: \(result ?? "未识别到二维码")")
        }
    }
    
    // 公开方法，用于外部调用，返回所有识别结果
    @MainActor
    func scanScreensForAllResults() async -> [String] {
        // 检查权限
        guard permissionManager.hasScreenRecordingPermission else {
            // 打开权限引导窗口
            NSApp.activate(ignoringOtherApps: true)
            // 创建并显示权限引导窗口
            let permissionWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            permissionWindow.center()
            permissionWindow.title = "权限引导"
            permissionWindow.contentView = NSHostingView(rootView: PermissionView().environmentObject(permissionManager))
            permissionWindow.makeKeyAndOrderFront(nil)
            return []
        }
        
        // 获取所有显示器
        let displays = NSScreen.screens
        
        var allResults: [String] = []
        
        for display in displays {
            if let image = captureDisplay(display) {
                if let contents = await qrCodeScanner.scanQRCode(from: image) {
                    // 识别成功，添加到结果数组
                    allResults += contents
                }
            }
        }
        
        if !allResults.isEmpty {
            // 去重结果
            let uniqueResults = Array(Set(allResults))
            
            // 添加到历史记录
            for content in uniqueResults {
                qrHistoryManager.addItem(content: content)
            }
            
            return uniqueResults
        }
        
        return []
    }
    
    // 公开方法，用于外部调用
    @MainActor
    func scanScreens() async -> String? {
        let results = await scanScreensForAllResults()
        return results.first
    }
    
    @MainActor
    @objc private func showHistory() {
        // 打开历史记录窗口
        NSApp.activate(ignoringOtherApps: true)
        // 创建并显示历史记录窗口
        let historyWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        historyWindow.center()
        historyWindow.title = "历史记录"
        
        // 创建 SwiftUI 视图并设置环境对象
        let historyView = HistoryView().environmentObject(qrHistoryManager)
        let hostingView = NSHostingView(rootView: historyView)
        historyWindow.contentView = hostingView
        
        // 设置窗口关闭处理程序
        historyWindow.isReleasedWhenClosed = false
        
        historyWindow.makeKeyAndOrderFront(nil)
    }
    
    @MainActor
    @objc private func openMainWindow() {
        // 激活应用
        NSApp.activate(ignoringOtherApps: true)
        
        // 简化的窗口查找逻辑：优先查找已存在的macQR窗口
        if let existingWindow = NSApp.windows.first(where: { $0.title == "macQR" }) {
            // 如果找到现有窗口，激活并显示它
            if existingWindow.isMiniaturized {
                existingWindow.deminiaturize(nil)
            }
            existingWindow.makeKeyAndOrderFront(nil)
            logMessage("复用现有macQR窗口")
            return
        }
        
        // 窗口尺寸适配：根据屏幕大小调整窗口尺寸
        let (windowWidth, windowHeight) = getOptimalWindowSize()
        
        // 创建窗口，使用标准的样式掩码，确保与SwiftUI窗口一致
        let mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // 窗口状态记忆功能：从UserDefaults读取之前保存的窗口位置和大小
        loadWindowState(mainWindow)
        
        // 配置窗口属性，与SwiftUI默认窗口保持一致
        mainWindow.title = "macQR"
        mainWindow.titlebarAppearsTransparent = false
        mainWindow.isMovableByWindowBackground = false
        mainWindow.isReleasedWhenClosed = false
        
        // 确保窗口按钮都可用
        mainWindow.standardWindowButton(.closeButton)?.isEnabled = true
        mainWindow.standardWindowButton(.miniaturizeButton)?.isEnabled = true
        mainWindow.standardWindowButton(.zoomButton)?.isEnabled = true
        
        // 添加窗口状态保存通知
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: mainWindow, queue: nil) {
            [weak self] _ in
            self?.saveWindowState(mainWindow)
        }
        
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: mainWindow, queue: nil) {
            [weak self] _ in
            self?.saveWindowState(mainWindow)
        }
        
        // 创建SwiftUI视图并设置环境对象
        let mainView = ContentView()
            .environmentObject(permissionManager)
            .environmentObject(qrHistoryManager)
        
        // 使用AppKitWindowHostingView来确保与SwiftUI自动创建的窗口完全一致
        let hostingView = NSHostingView(rootView: mainView)
        mainWindow.contentView = hostingView
        
        // 显示窗口并将其置于最前面
        mainWindow.makeKeyAndOrderFront(nil)
        
        logMessage("创建新的macQR窗口")
    }
    
    // MARK: - Window Management Helper Methods
    
    /// 获取最佳窗口尺寸，根据屏幕大小自动调整
    private func getOptimalWindowSize() -> (width: CGFloat, height: CGFloat) {
        // 获取当前屏幕
        guard let currentScreen = NSApp.mainWindow?.screen ?? NSScreen.main else {
            return (700, 600) // 默认尺寸
        }
        
        // 屏幕可用区域
        let screenVisibleFrame = currentScreen.visibleFrame
        let screenWidth = screenVisibleFrame.width
        let screenHeight = screenVisibleFrame.height
        
        // 计算最佳窗口尺寸，不超过屏幕可用区域的80%
        let maxWidth = min(screenWidth * 0.8, 900) // 最大宽度900px
        let maxHeight = min(screenHeight * 0.8, 700) // 最大高度700px
        
        // 最小窗口尺寸
        let minWidth: CGFloat = 600
        let minHeight: CGFloat = 500
        
        // 确保窗口尺寸在合理范围内
        let windowWidth = max(minWidth, maxWidth)
        let windowHeight = max(minHeight, maxHeight)
        
        return (windowWidth, windowHeight)
    }
    
    /// 保存窗口状态到UserDefaults
    private func saveWindowState(_ window: NSWindow) {
        let userDefaults = UserDefaults.standard
        
        // 保存窗口位置和大小
        userDefaults.set(window.frame.origin.x, forKey: "mainWindowX")
        userDefaults.set(window.frame.origin.y, forKey: "mainWindowY")
        userDefaults.set(window.frame.size.width, forKey: "mainWindowWidth")
        userDefaults.set(window.frame.size.height, forKey: "mainWindowHeight")
        
        // 记录日志
        logMessage("保存窗口状态: \(window.frame)")
    }
    
    /// 从UserDefaults加载窗口状态
    private func loadWindowState(_ window: NSWindow) {
        let userDefaults = UserDefaults.standard
        
        // 获取最佳窗口尺寸
        let (defaultWidth, defaultHeight) = getOptimalWindowSize()
        
        // 从UserDefaults读取窗口状态
        let savedX = userDefaults.double(forKey: "mainWindowX")
        let savedY = userDefaults.double(forKey: "mainWindowY")
        let savedWidth = userDefaults.double(forKey: "mainWindowWidth")
        let savedHeight = userDefaults.double(forKey: "mainWindowHeight")
        
        // 检查是否有有效的保存状态
        if savedWidth > 0 && savedHeight > 0 {
            // 计算窗口矩形
            let windowRect = NSRect(
                x: CGFloat(savedX),
                y: CGFloat(savedY),
                width: CGFloat(savedWidth),
                height: CGFloat(savedHeight)
            )
            
            // 检查窗口是否在任何屏幕的可见区域内
            if isWindowRectVisible(windowRect) {
                // 如果窗口在可见区域内，使用保存的位置和大小
                window.setFrame(windowRect, display: false)
                logMessage("使用保存的窗口状态: \(windowRect)")
                return
            }
        }
        
        // 如果没有保存的状态或窗口不在可见区域内，使用最佳尺寸并居中显示
        centerWindowOnCurrentScreen(window, width: defaultWidth, height: defaultHeight)
        logMessage("使用默认窗口状态: 宽度=\(defaultWidth), 高度=\(defaultHeight)")
    }
    
    /// 检查窗口矩形是否在任何屏幕的可见区域内
    private func isWindowRectVisible(_ rect: NSRect) -> Bool {
        for screen in NSScreen.screens {
            let screenVisibleFrame = screen.visibleFrame
            if rect.intersects(screenVisibleFrame) {
                return true
            }
        }
        return false
    }
    
    /// 在当前活跃屏幕上居中显示窗口
    private func centerWindowOnCurrentScreen(_ window: NSWindow, width: CGFloat, height: CGFloat) {
        // 多屏幕显示策略：在当前活跃屏幕上居中显示窗口
        if let currentScreen = NSApp.mainWindow?.screen ?? NSScreen.main {
            let screenRect = currentScreen.visibleFrame
            let windowRect = NSRect(
                x: screenRect.midX - width / 2,
                y: screenRect.midY - height / 2,
                width: width,
                height: height
            )
            window.setFrame(windowRect, display: false)
        } else {
            // 如果无法获取当前屏幕，使用默认的居中方法
            window.setFrame(NSRect(x: 0, y: 0, width: width, height: height), display: false)
            window.center()
        }
    }
    
    @MainActor
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - QR Scanning
    @MainActor
    private func scanAllScreens() async -> String? {
        // 检查权限
        guard permissionManager.hasScreenRecordingPermission else {
            // 打开权限引导窗口
            NSApp.activate(ignoringOtherApps: true)
            // 创建并显示权限引导窗口
            let permissionWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            permissionWindow.center()
            permissionWindow.title = "权限引导"
            permissionWindow.contentView = NSHostingView(rootView: PermissionView().environmentObject(permissionManager))
            permissionWindow.makeKeyAndOrderFront(nil)
            return nil
        }
        
        // 获取所有显示器
        let displays = NSScreen.screens
        
        var allResults: [String] = []
        
        for display in displays {
            if let image = captureDisplay(display) {
                if let contents = await qrCodeScanner.scanQRCode(from: image) {
                    // 识别成功，添加到结果数组
                    allResults += contents
                }
            }
        }
        
        if !allResults.isEmpty {
            // 去重结果
            let uniqueResults = Array(Set(allResults))
            
            // 添加到历史记录
            for content in uniqueResults {
                qrHistoryManager.addItem(content: content)
            }
            
            // 复制第一个结果到剪贴板
            let firstResult = uniqueResults.first!
            copyToClipboard(firstResult)
            
            // 更新最新识别结果
            latestQRResult = (content: firstResult, timestamp: Date())
            updateResultMenuItem()
            
            if uniqueResults.count == 1 {
                // 只识别到一个二维码
                // 显示通知 - 截断长文本，最多显示100个字符
                let truncatedContent = firstResult.count > 100 ? String(firstResult.prefix(100)) + "..." : firstResult
                showNotification(title: "二维码信息已复制", subtitle: truncatedContent)
                // 记录日志
                logMessage("识别成功: \(firstResult)")
                return firstResult // 返回识别到的二维码内容
            } else {
                // 识别到多个二维码
                showNotification(title: "识别到 \(uniqueResults.count) 个二维码", subtitle: "将自动为您打开识别记录")
                
                // 自动打开历史记录窗口
                showHistory()
                
                // 记录日志
                logMessage("识别成功: \(uniqueResults.count) 个二维码")
                return firstResult // 返回第一个识别到的二维码内容
            }
        }
        
        // 没有识别到二维码
        // 更新最新识别结果为nil
        latestQRResult = nil
        updateResultMenuItem()
        
        // 显示通知
        showNotification(title: "识别失败", subtitle: "未在屏幕上找到二维码")
        // 记录日志
        logMessage("识别失败: 未在屏幕上找到二维码")
        return nil
    }
    
    private func captureDisplay(_ display: NSScreen) -> NSImage? {
        let rect = display.frame
        
        // 安全获取屏幕编号
        guard let screenNumber = display.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let cgImage = CGDisplayCreateImage(CGDirectDisplayID(screenNumber.int32Value)) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: rect.size)
    }
    
    private func copyToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
    
    // MARK: - Notifications
    @MainActor
    private func showNotification(title: String, subtitle: String) {
        // 开始处理通知
        let startTime = Date()
        let notificationId = UUID().uuidString
        let logPrefix = "[通知ID: \(notificationId)]"
        
        // 打印并记录详细的开始日志
        let startLogMessage = "\(logPrefix) 开始处理通知: \(title) - \(subtitle)"
        print("[DEBUG] \(startLogMessage)")
        logMessage(startLogMessage)
        
        // 检查是否是命令行调试环境
        let isCommandLineEnvironment = Bundle.main.bundleURL.pathExtension != "app"
        let commandLineLogMessage = "\(logPrefix) 是否是命令行环境: \(isCommandLineEnvironment)"
        print("[DEBUG] \(commandLineLogMessage)")
        logMessage(commandLineLogMessage)
        
        // 只在非命令行环境下发送通知
        guard !isCommandLineEnvironment else {
            let endTime = Date()
            let processingTime = endTime.timeIntervalSince(startTime)
            let skipLogMessage = "\(logPrefix) 命令行环境下，跳过发送通知, 耗时: \(processingTime)秒"
            print("[DEBUG] \(skipLogMessage)")
            logMessage(skipLogMessage)
            return
        }
        
        // 检查应用程序bundle是否有效，避免在命令行环境下崩溃
        let bundleURL = Bundle.main.bundleURL
        let isAppBundle = bundleURL.pathExtension == "app"
        let bundleLogMessage = "\(logPrefix) 应用程序bundle路径: \(bundleURL.path), 是否是.app包: \(isAppBundle)"
        print("[DEBUG] \(bundleLogMessage)")
        logMessage(bundleLogMessage)
        
        guard isAppBundle else {
            let endTime = Date()
            let processingTime = endTime.timeIntervalSince(startTime)
            let invalidBundleLogMessage = "\(logPrefix) 应用程序bundle不是.app包，跳过发送通知, 耗时: \(processingTime)秒"
            print("[DEBUG] \(invalidBundleLogMessage)")
            logMessage(invalidBundleLogMessage)
            return
        }
        
        // 直接使用UNUserNotificationCenter API进行权限检查和请求
        let center = UNUserNotificationCenter.current()
        let centerLogMessage = "\(logPrefix) 获取UNUserNotificationCenter实例成功"
        print("[DEBUG] \(centerLogMessage)")
        logMessage(centerLogMessage)
        
        // 步骤1: 获取当前通知设置
        let getSettingsLogMessage = "\(logPrefix) 开始获取通知设置"
        print("[DEBUG] \(getSettingsLogMessage)")
        logMessage(getSettingsLogMessage)
        
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { 
                print("[DEBUG] \(logPrefix) self已释放，无法继续处理通知")
                return 
            }
            
            let endTime = Date()
            let processingTime = endTime.timeIntervalSince(startTime)
            
            // 记录完整的权限状态
            let permissionStatus = settings.authorizationStatus
            let authStatus = settings.authorizationStatus
            let notificationCenterSetting = settings.notificationCenterSetting
            let soundSetting = settings.soundSetting
            let badgeSetting = settings.badgeSetting
            let lockScreenSetting = settings.lockScreenSetting
            
            let settingsLogMessage = "\(logPrefix) 获取通知设置完成，权限状态: \(permissionStatus), 通知中心设置: \(settings.notificationCenterSetting), 声音设置: \(settings.soundSetting), 徽章设置: \(settings.badgeSetting), 锁屏设置: \(settings.lockScreenSetting), 耗时: \(processingTime)秒"
            print("[DEBUG] \(settingsLogMessage)")
            self.logMessage(settingsLogMessage)
            
            switch permissionStatus {
            case .authorized:
                // 权限已授权，发送通知
                let authorizedLogMessage = "\(logPrefix) 权限已授权，准备发送通知"
                print("[DEBUG] \(authorizedLogMessage)")
                self.logMessage(authorizedLogMessage)
                // 调用sendNotification方法
                Task { @MainActor in
                    self.sendNotification(title: title, subtitle: subtitle, notificationId: notificationId, startTime: startTime)
                }
                
            case .notDetermined:
                // 尚未决定，请求权限
                let requestPermissionLogMessage = "\(logPrefix) 权限尚未决定，正在请求权限"
                print("[DEBUG] \(requestPermissionLogMessage)")
                self.logMessage(requestPermissionLogMessage)
                
                // 记录请求的权限选项
                let notificationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]
                let optionsLogMessage = "\(logPrefix) 请求的通知权限选项: \(notificationOptions)"
                print("[DEBUG] \(optionsLogMessage)")
                self.logMessage(optionsLogMessage)
                
                center.requestAuthorization(options: notificationOptions) { [weak self] granted, error in
                    guard let self = self else { 
                        print("[DEBUG] \(logPrefix) self已释放，无法处理权限请求结果")
                        return 
                    }
                    
                    let endTime = Date()
                    let processingTime = endTime.timeIntervalSince(startTime)
                    
                    if let error = error {
                        // 权限请求失败
                        let nsError = error as NSError
                        let errorLogMessage = "\(logPrefix) 请求权限失败: 错误=\(error), 代码=\(nsError.code), 描述=\(nsError.localizedDescription), 耗时: \(processingTime)秒"
                        print("[DEBUG] \(errorLogMessage)")
                        self.logMessage(errorLogMessage)
                    } else {
                        // 权限请求结果
                        let resultLogMessage = "\(logPrefix) 请求权限完成，结果: \(granted), 耗时: \(processingTime)秒"
                        print("[DEBUG] \(resultLogMessage)")
                        self.logMessage(resultLogMessage)
                        
                        if granted {
                            // 权限已获得，发送通知
                            let grantedLogMessage = "\(logPrefix) 请求权限成功，准备发送通知"
                            print("[DEBUG] \(grantedLogMessage)")
                            self.logMessage(grantedLogMessage)
                            // 调用sendNotification方法
                            Task { @MainActor in
                                self.sendNotification(title: title, subtitle: subtitle, notificationId: notificationId, startTime: startTime)
                            }
                        } else {
                            // 权限被拒绝
                            let deniedLogMessage = "\(logPrefix) 请求权限被拒绝，无法发送通知"
                            print("[DEBUG] \(deniedLogMessage)")
                            self.logMessage(deniedLogMessage)
                        }
                    }
                }
                
            case .denied:
                // 权限被拒绝
                let deniedLogMessage = "\(logPrefix) 权限状态为.denied，无法发送通知, 耗时: \(processingTime)秒"
                print("[DEBUG] \(deniedLogMessage)")
                self.logMessage(deniedLogMessage)
                
                // 权限被拒绝时，提示用户可以通过菜单打开通知设置
                let tipLogMessage = "\(logPrefix) 提示: 可以通过菜单栏的'打开通知设置'选项来启用通知权限"
                print("[DEBUG] \(tipLogMessage)")
                self.logMessage(tipLogMessage)
                
            case .provisional:
                // 临时权限
                let provisionalLogMessage = "\(logPrefix) 权限状态为.provisional，准备发送通知, 耗时: \(processingTime)秒"
                print("[DEBUG] \(provisionalLogMessage)")
                self.logMessage(provisionalLogMessage)
                // 调用sendNotification方法
                Task { @MainActor in
                    self.sendNotification(title: title, subtitle: subtitle, notificationId: notificationId, startTime: startTime)
                }
                
            case .ephemeral:
                // 短暂权限
                let ephemeralLogMessage = "\(logPrefix) 权限状态为.ephemeral，准备发送通知, 耗时: \(processingTime)秒"
                print("[DEBUG] \(ephemeralLogMessage)")
                self.logMessage(ephemeralLogMessage)
                // 调用sendNotification方法
                Task { @MainActor in
                    self.sendNotification(title: title, subtitle: subtitle, notificationId: notificationId, startTime: startTime)
                }
                
            @unknown default:
                // 未知状态
                let unknownLogMessage = "\(logPrefix) 未知权限状态，无法发送通知, 耗时: \(processingTime)秒"
                print("[DEBUG] \(unknownLogMessage)")
                self.logMessage(unknownLogMessage)
            }
        }
    }
    
    // 发送通知的核心方法
    @MainActor
    private func sendNotification(title: String, subtitle: String, notificationId: String, startTime: Date) {
        let logPrefix = "[通知ID: \(notificationId)]"
        
        // 构建通知内容
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.sound = UNNotificationSound.default
        
        // 记录通知内容
        let soundDescription = String(describing: content.sound)
        print("[DEBUG] \(logPrefix) 通知内容: 标题=\(content.title), 副标题=\(content.subtitle), 声音=\(soundDescription)")
        logMessage("\(logPrefix) 通知内容: 标题=\(content.title), 副标题=\(content.subtitle), 声音=\(soundDescription)")
        
        // 创建通知请求
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: nil
        )
        
        print("[DEBUG] \(logPrefix) 通知请求创建完成")
        logMessage("\(logPrefix) 通知请求创建完成")
        
        // 发送通知请求
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            guard let self = self else { return }
            
            let endTime = Date()
            let processingTime = endTime.timeIntervalSince(startTime)
            
            if let error = error {
                print("[DEBUG] \(logPrefix) 发送通知失败, 耗时: \(processingTime)秒, 错误: \(error)")
                self.logMessage("\(logPrefix) 发送通知失败: \(error)")
            } else {
                print("[DEBUG] \(logPrefix) 发送通知成功, 耗时: \(processingTime)秒")
                self.logMessage("\(logPrefix) 通知发送成功: \(title) - \(subtitle)")
            }
        }
    }
    
    // MARK: - Logging
    // 记录日志到文件 - 标记为nonisolated，允许在非隔离上下文中调用
    nonisolated func logMessage(_ message: String) {
        // 获取当前时间
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        // 构建日志内容
        let logContent = "[\(timestamp)] \(message)\n"
        
        // 获取日志文件路径 - 设置为指定位置
        let logDirectory = URL(fileURLWithPath: "/Users/way/mac/macQR/Sources/macQR")
        let logFilePath = logDirectory.appendingPathComponent("macQR.log")
        
        // 写入日志
        do {
            // 确保日志目录存在
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: logDirectory.path) {
                try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // 使用文件句柄追加写入，更高效
            let fileHandle = try FileHandle(forWritingTo: logFilePath)
            fileHandle.seekToEndOfFile()
            fileHandle.write(logContent.data(using: .utf8)!)
            fileHandle.closeFile()
        } catch let error as NSError where error.code == 2 { // 文件不存在
            // 文件不存在，创建新文件
            do {
                try logContent.write(to: logFilePath, atomically: true, encoding: .utf8)
            } catch {
                // 只在开发环境下打印错误日志
                #if DEBUG
                print("[ERROR] 创建日志文件失败: \(error)")
                #endif
            }
        } catch {
            // 只在开发环境下打印错误日志
            #if DEBUG
            print("[ERROR] 写入日志失败: \(error)")
            #endif
        }
    }
}