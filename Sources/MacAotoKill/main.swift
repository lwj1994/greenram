import AppKit
import MacAotoKillCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = StatusMenuController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
