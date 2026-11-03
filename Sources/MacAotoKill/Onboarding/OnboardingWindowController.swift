import AppKit
import MacAotoKillCore
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let localizerProvider: () -> Localizer
    private let onFinish: () -> Void
    private let onClose: () -> Void

    var isOpen: Bool {
        window?.isVisible ?? false
    }

    init(
        localizerProvider: @escaping () -> Localizer,
        onFinish: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.localizerProvider = localizerProvider
        self.onFinish = onFinish
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: OnboardingView.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = AppIdentity.name
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 每次显示都从第一页开始，并使用当前语言。
    func show() {
        let hostingController = NSHostingController(
            rootView: OnboardingView(localizer: localizerProvider(), onFinish: onFinish)
        )
        hostingController.sizingOptions = []
        window?.contentViewController = hostingController
        window?.setContentSize(OnboardingView.size)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.onClose()
        }
    }
}
