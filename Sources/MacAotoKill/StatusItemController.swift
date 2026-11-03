import AppKit
import SwiftUI

/// 菜单栏叶子图标，点击弹出 SwiftUI 面板。
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let onWillShow: () -> Void
    private let onVisibilityChange: () -> Void
    private var isExceeded: Bool?

    var isPopoverShown: Bool {
        popover.isShown
    }

    init<Content: View>(
        content: Content,
        onWillShow: @escaping () -> Void,
        onVisibilityChange: @escaping () -> Void
    ) {
        self.onWillShow = onWillShow
        self.onVisibilityChange = onVisibilityChange
        super.init()

        let hostingController = NSHostingController(rootView: content)
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func update(isExceeded: Bool, toolTip: String) {
        if self.isExceeded != isExceeded {
            self.isExceeded = isExceeded
            statusItem.button?.image = LeafGlyph.statusImage(isExceeded: isExceeded)
        }
        statusItem.button?.toolTip = toolTip
    }

    func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        guard let button = statusItem.button else { return }
        onWillShow()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidShow(_ notification: Notification) {
        onVisibilityChange()
    }

    func popoverDidClose(_ notification: Notification) {
        onVisibilityChange()
    }
}
