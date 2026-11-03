import AppKit
import AppleViewModel
import MacAotoKillCore
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private static let frameAutosaveName = "GreenRAMMainWindow"
    private let onVisibilityChange: () -> Void

    var isOpen: Bool {
        window?.isVisible ?? false
    }

    var isVisibleOnScreen: Bool {
        guard let window else { return false }
        return window.isVisible && window.occlusionState.contains(.visible)
    }

    init(
        dashboardSpec: ViewModelSpec<DashboardViewModel>,
        settingsSpec: ViewModelSpec<SettingsViewModel>,
        onVisibilityChange: @escaping () -> Void
    ) {
        self.onVisibilityChange = onVisibilityChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = AppIdentity.name
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.fullScreenPrimary)
        super.init(window: window)

        let hostingController = NSHostingController(
            rootView: MainView(dashboardSpec: dashboardSpec, settingsSpec: settingsSpec)
        )
        hostingController.sizingOptions = []
        window.contentViewController = hostingController
        window.contentMinSize = NSSize(width: 920, height: 620)
        window.setContentSize(NSSize(width: 1120, height: 760))
        window.delegate = self
        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(occlusionStateDidChange(_:)),
            name: NSWindow.didChangeOcclusionStateNotification,
            object: window
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onVisibilityChange()
    }

    func windowWillClose(_ notification: Notification) {
        // 关闭动画结束后 isVisible 才变为 false。
        DispatchQueue.main.async { [weak self] in
            self?.onVisibilityChange()
        }
    }

    @objc private func occlusionStateDidChange(_ notification: Notification) {
        onVisibilityChange()
    }
}
