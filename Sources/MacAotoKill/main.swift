import AppKit
import AppleViewModel
import MacAotoKillCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusMenuController?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        ViewModel.initialize()
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
