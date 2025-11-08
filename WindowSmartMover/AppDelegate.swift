import Cocoa
import Carbon
import SwiftUI

// グローバル変数としてAppDelegateの参照を保持
private var globalAppDelegate: AppDelegate?

// Cイベントハンドラー
private func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    
    guard status == noErr else {
        return status
    }
    
    guard let appDelegate = globalAppDelegate else {
        return OSStatus(eventNotHandledErr)
    }
    
    print("🔥 ホットキーが押されました: ID = \(hotKeyID.id)")
    
    DispatchQueue.main.async {
        switch hotKeyID.id {
        case 1: // 右矢印（次の画面）
            appDelegate.moveWindowToNextScreen()
        case 2: // 左矢印（前の画面）
            appDelegate.moveWindowToPrevScreen()
        default:
            break
        }
    }
    
    return noErr
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hotKeyRef: EventHotKeyRef?
    var hotKeyRef2: EventHotKeyRef?
    var eventHandler: EventHandlerRef?
    var settingsWindow: NSWindow?
    var aboutWindow: NSWindow?
    
    // ディスプレイ記憶機能
    // [ディスプレイID: [ウィンドウID: 座標]]
    private var windowPositions: [String: [String: CGRect]] = [:]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // グローバル参照を設定
        globalAppDelegate = self
        
        // システムバーにアイコンを追加
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.2.swap", accessibilityDescription: "Window Mover")
            button.image?.isTemplate = true
        }
        
        // メニューを設定
        setupMenu()
        
        // グローバルホットキーを登録
        registerHotKeys()
        
        // アクセシビリティ権限をチェック
        checkAccessibilityPermissions()
        
        // ディスプレイ変更の監視を開始
        setupDisplayChangeObserver()
        
        debugPrint("アプリが起動しました")
        debugPrint("接続されている画面数: \(NSScreen.screens.count)")
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        let modifierString = HotKeySettings.shared.getModifierString()
        menu.addItem(NSMenuItem(title: "ウィンドウを次の画面へ (\(modifierString)→)", action: #selector(moveWindowToNextScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "ウィンドウを前の画面へ (\(modifierString)←)", action: #selector(moveWindowToPrevScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "ショートカット設定...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "デバッグ情報を表示", action: #selector(showDebugInfo), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About WindowSmartMover", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "設定"
            window.styleMask = [.titled, .closable]
            window.center()
            window.level = .floating
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func openAbout() {
        if aboutWindow == nil {
            let aboutView = AboutView()
            let hostingController = NSHostingController(rootView: aboutView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "About"
            window.styleMask = [.titled, .closable]
            window.center()
            window.level = .floating
            
            aboutWindow = window
        }
        
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func registerHotKeys() {
        // 既存のホットキーを解除
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
            hotKeyRef = nil
        }
        if let hotKey = hotKeyRef2 {
            UnregisterEventHotKey(hotKey)
            hotKeyRef2 = nil
        }
        
        // イベントタイプの指定
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // イベントハンドラをインストール（初回のみ）
        if eventHandler == nil {
            let status = InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, &eventHandler)
            
            if status == noErr {
                debugPrint("✅ イベントハンドラのインストール成功")
            } else {
                debugPrint("❌ イベントハンドラのインストール失敗: \(status)")
            }
        }
        
        // 設定から修飾キーを取得
        let modifiers = HotKeySettings.shared.getModifiers()
        let modifierString = HotKeySettings.shared.getModifierString()
        
        // Ctrl + Option + Command + 右矢印
        var gMyHotKeyID1 = EventHotKeyID(signature: OSType(0x4D4F5652), id: 1) // 'MOVR'
        var hotKey1: EventHotKeyRef?
        let registerStatus1 = RegisterEventHotKey(UInt32(kVK_RightArrow), modifiers, gMyHotKeyID1, GetApplicationEventTarget(), 0, &hotKey1)
        
        if registerStatus1 == noErr {
            hotKeyRef = hotKey1
            debugPrint("✅ ホットキー1 (\(modifierString)→) の登録成功")
        } else {
            debugPrint("❌ ホットキー1 の登録失敗: \(registerStatus1)")
        }
        
        // Ctrl + Option + Command + 左矢印
        var gMyHotKeyID2 = EventHotKeyID(signature: OSType(0x4D4F564C), id: 2) // 'MOVL'
        var hotKey2: EventHotKeyRef?
        let registerStatus2 = RegisterEventHotKey(UInt32(kVK_LeftArrow), modifiers, gMyHotKeyID2, GetApplicationEventTarget(), 0, &hotKey2)
        
        if registerStatus2 == noErr {
            hotKeyRef2 = hotKey2
            debugPrint("✅ ホットキー2 (\(modifierString)←) の登録成功")
        } else {
            debugPrint("❌ ホットキー2 の登録失敗: \(registerStatus2)")
        }
    }
    
    @objc func moveWindowToNextScreen() {
        debugPrint("=== 次の画面への移動を開始 ===")
        moveWindow(direction: 1)
    }
    
    @objc func moveWindowToPrevScreen() {
        debugPrint("=== 前の画面への移動を開始 ===")
        moveWindow(direction: -1)
    }
    
    func moveWindow(direction: Int) {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            debugPrint("❌ フロントアプリを取得できませんでした")
            return
        }
        
        debugPrint("フロントアプリ: \(frontmostApp.localizedName ?? "不明")")
        
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        
        // フロントアプリのメインウィンドウを探す
        guard let windows = windowList,
              let targetWindow = windows.first(where: { window in
                  guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                        ownerPID == frontmostApp.processIdentifier,
                        let layer = window[kCGWindowLayer as String] as? Int,
                        layer == 0 else { return false }
                  return true
              }),
              let boundsDict = targetWindow[kCGWindowBounds as String] as? [String: CGFloat]
        else {
            debugPrint("❌ ターゲットウィンドウが見つかりませんでした")
            return
        }
        
        let currentFrame = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
        
        debugPrint("現在のウィンドウ位置: \(currentFrame)")
        
        // 現在のウィンドウがある画面を特定
        let screens = NSScreen.screens
        guard let currentScreenIndex = screens.firstIndex(where: { screen in
            screen.frame.intersects(currentFrame)
        }) else {
            debugPrint("❌ 現在の画面を特定できませんでした")
            return
        }
        
        debugPrint("現在の画面インデックス: \(currentScreenIndex)")
        
        // 次の画面を計算
        let nextScreenIndex = (currentScreenIndex + direction + screens.count) % screens.count
        let targetScreen = screens[nextScreenIndex]
        
        debugPrint("移動先画面インデックス: \(nextScreenIndex)")
        debugPrint("移動先画面のフレーム: \(targetScreen.frame)")
        
        // ウィンドウの相対位置を維持して移動
        let currentScreen = screens[currentScreenIndex]
        let relativeX = currentFrame.origin.x - currentScreen.frame.origin.x
        let relativeY = currentFrame.origin.y - currentScreen.frame.origin.y
        
        let newX = targetScreen.frame.origin.x + relativeX
        let newY = targetScreen.frame.origin.y + relativeY
        
        debugPrint("新しい位置: x=\(newX), y=\(newY)")
        
        // Accessibility APIを使用してウィンドウを移動
        let appRef = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        // まずフォーカスウィンドウを試す
        var value: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &value)
        
        // フォーカスウィンドウが取得できない場合は、全ウィンドウリストから取得
        if result != .success {
            var windowList: CFTypeRef?
            result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList)
            
            if result == .success, let windows = windowList as? [AXUIElement], !windows.isEmpty {
                value = windows[0]
                result = .success
            }
        }
        
        if result == .success, let windowElement = value {
            // 現在の位置を確認
            var currentPos: CFTypeRef?
            if AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXPositionAttribute as CFString, &currentPos) == .success {
                var point = CGPoint.zero
                if AXValueGetValue(currentPos as! AXValue, .cgPoint, &point) {
                    debugPrint("現在のAX位置: \(point)")
                }
            }
            
            // 新しい位置を設定
            var position = CGPoint(x: newX, y: newY)
            
            if let positionValue = AXValueCreate(.cgPoint, &position) {
                let setResult = AXUIElementSetAttributeValue(windowElement as! AXUIElement, kAXPositionAttribute as CFString, positionValue)
                
                if setResult == .success {
                    debugPrint("✅ ウィンドウの移動に成功しました")
                } else {
                    debugPrint("❌ ウィンドウの移動に失敗: \(setResult.rawValue)")
                }
            }
        }
    }
    
    @objc func showDebugInfo() {
        debugPrint("\n=== デバッグ情報 ===")
        debugPrint("接続されている画面数: \(NSScreen.screens.count)")
        
        for (index, screen) in NSScreen.screens.enumerated() {
            debugPrint("画面 \(index): \(screen.frame)")
            let name = screen.localizedName
            debugPrint("  名前: \(name)")
        }
        
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            debugPrint("現在のフロントアプリ: \(frontmostApp.localizedName ?? "不明")")
        }
        
        debugPrint("アクセシビリティ権限: \(AXIsProcessTrusted())")
        debugPrint("現在のショートカット: \(HotKeySettings.shared.getModifierString())← / →")
        debugPrint("===================\n")
    }
    
    func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            debugPrint("⚠️ アクセシビリティ権限が必要です")
            
            let alert = NSAlert()
            alert.messageText = "アクセシビリティ権限が必要です"
            alert.informativeText = "このアプリはウィンドウを移動するためにアクセシビリティ権限が必要です。\n\nシステム設定 > プライバシーとセキュリティ > アクセシビリティ\nでこのアプリを許可してください。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "システム設定を開く")
            alert.addButton(withTitle: "あとで")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            debugPrint("✅ アクセシビリティ権限が付与されています")
        }
    }
    
    func debugPrint(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] \(message)")
    }
    
    // MARK: - ディスプレイ記憶機能
    
    /// ディスプレイ変更の監視を開始
    private func setupDisplayChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        debugPrint("✅ ディスプレイ変更の監視を開始しました")
    }
    
    /// ディスプレイ構成が変更された時の処理
    @objc private func screenParametersDidChange(_ notification: Notification) {
        debugPrint("\n=== ディスプレイ構成が変更されました ===")
        
        let currentScreens = NSScreen.screens
        let currentScreenIDs = currentScreens.map { getDisplayIdentifier(for: $0) }
        
        debugPrint("現在の画面数: \(currentScreens.count)")
        for (index, screen) in currentScreens.enumerated() {
            let id = getDisplayIdentifier(for: screen)
            debugPrint("  画面\(index): \(id)")
        }
        
        // 消えた画面を検出
        let savedScreenIDs = Set(windowPositions.keys)
        let removedScreenIDs = savedScreenIDs.subtracting(currentScreenIDs)
        
        if !removedScreenIDs.isEmpty {
            debugPrint("⚠️ 外れた画面: \(removedScreenIDs.joined(separator: ", "))")
            // 外れた画面の情報は保持（再接続時に復元するため）
        }
        
        // 追加された画面を検出
        let addedScreenIDs = Set(currentScreenIDs).subtracting(savedScreenIDs)
        
        if !addedScreenIDs.isEmpty {
            debugPrint("✅ 接続された画面: \(addedScreenIDs.joined(separator: ", "))")
            // 少し待ってから復元（画面が安定するまで）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.restoreWindowsForScreens(addedScreenIDs)
            }
        }
        
        // 現在の全ウィンドウ位置を保存
        saveAllWindowPositions()
    }
    
    /// ディスプレイの識別子を生成（名前+解像度）
    private func getDisplayIdentifier(for screen: NSScreen) -> String {
        let name = screen.localizedName
        let width = Int(screen.frame.width)
        let height = Int(screen.frame.height)
        return "\(name)_\(width)x\(height)"
    }
    
    /// ウィンドウの識別子を生成（アプリ名+ウィンドウタイトル）
    private func getWindowIdentifier(appName: String, windowTitle: String) -> String {
        return "\(appName)_\(windowTitle)"
    }
    
    /// 全ウィンドウの位置を保存
    private func saveAllWindowPositions() {
        debugPrint("📝 全ウィンドウの位置を保存中...")
        
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            debugPrint("❌ ウィンドウリストの取得に失敗")
            return
        }
        
        let screens = NSScreen.screens
        var savedCount = 0
        
        for window in windowList {
            // layer 0（通常のウィンドウ）のみ対象
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let ownerName = window[kCGWindowOwnerName as String] as? String else {
                continue
            }
            
            let windowTitle = (window[kCGWindowName as String] as? String) ?? "Untitled"
            let windowID = getWindowIdentifier(appName: ownerName, windowTitle: windowTitle)
            
            let frame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            // このウィンドウがどの画面にあるか判定
            for screen in screens {
                if screen.frame.intersects(frame) {
                    let displayID = getDisplayIdentifier(for: screen)
                    
                    if windowPositions[displayID] == nil {
                        windowPositions[displayID] = [:]
                    }
                    windowPositions[displayID]?[windowID] = frame
                    savedCount += 1
                    break
                }
            }
        }
        
        debugPrint("✅ \(savedCount)個のウィンドウ位置を保存しました")
    }
    
    /// 指定された画面のウィンドウを復元
    private func restoreWindowsForScreens(_ screenIDs: Set<String>) {
        debugPrint("🔄 ウィンドウ位置の復元を開始...")
        
        var restoredCount = 0
        
        for screenID in screenIDs {
            guard let savedWindows = windowPositions[screenID] else {
                debugPrint("  画面 \(screenID) の保存情報がありません")
                continue
            }
            
            debugPrint("  画面 \(screenID) に \(savedWindows.count)個のウィンドウを復元します")
            
            // 現在の全ウィンドウを取得
            let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
            guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
                continue
            }
            
            for (windowID, savedFrame) in savedWindows {
                // windowIDからアプリ名を抽出
                let components = windowID.split(separator: "_", maxSplits: 1)
                guard components.count >= 1 else { continue }
                let appName = String(components[0])
                
                // 該当するウィンドウを探す
                for window in windowList {
                    guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                          ownerName == appName,
                          let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                          let layer = window[kCGWindowLayer as String] as? Int,
                          layer == 0 else {
                        continue
                    }
                    
                    // Accessibility APIでウィンドウを移動
                    let appRef = AXUIElementCreateApplication(ownerPID)
                    var windowList: CFTypeRef?
                    let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList)
                    
                    if result == .success, let windows = windowList as? [AXUIElement], !windows.isEmpty {
                        // 最初のウィンドウを移動（簡易版）
                        var position = CGPoint(x: savedFrame.origin.x, y: savedFrame.origin.y)
                        if let positionValue = AXValueCreate(.cgPoint, &position) {
                            let setResult = AXUIElementSetAttributeValue(windows[0], kAXPositionAttribute as CFString, positionValue)
                            if setResult == .success {
                                restoredCount += 1
                                debugPrint("    ✅ \(windowID) を復元しました")
                            }
                        }
                        break
                    }
                }
            }
        }
        
        debugPrint("✅ \(restoredCount)個のウィンドウを復元しました\n")
    }
    
    deinit {
        // ホットキーの登録解除
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
        }
        if let hotKey = hotKeyRef2 {
            UnregisterEventHotKey(hotKey)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}
