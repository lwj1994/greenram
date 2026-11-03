import AppKit
import AppleViewModel
import MacAotoKillCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        ViewModel.initialize()
        NSApp.setActivationPolicy(.accessory)
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        coordinator.start()
    }

    /// 运行中再次从 Finder / Dock 打开 GreenRAM 时，显示主窗口。
    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator?.openMainWindow(page: nil)
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }
}

/// `swift run` 启动的是裸可执行文件，没有 .app 包里的 CFBundleIconFile，Dock 上会是空白图标。
/// 开发构建在没有 bundle 时直接用仓库里的 icns；打包后的 App 不走这里。
enum DevelopmentAppIcon {
    @MainActor
    static func applyIfNeeded() {
        #if DEBUG
        guard Bundle.main.bundleIdentifier == nil else { return }
        let iconURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Packaging/GreenRAM.icns")
        if let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        #endif
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
