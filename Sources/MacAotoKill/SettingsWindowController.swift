import AppKit
import AppleViewModel
import MacAotoKillCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsViewModelBinding: ViewModelBinding
    private let viewModelSpec: ViewModelSpec<SettingsViewModel>
    private let viewModel: SettingsViewModel

    init(
        settingsStore: SettingsStore,
        whitelistStore: WhitelistStore,
        memoryProvider: @escaping () -> SystemMemorySnapshot,
        onChange: @escaping () -> Void,
        onWhitelistAdded: @escaping (String) -> Void,
        onWhitelistRemoved: @escaping (String) -> Void,
        onExportLogs: @escaping () -> Void
    ) {
        let settingsViewModelBinding = ViewModelBinding()
        let viewModelSpec = ViewModelSpec<SettingsViewModel>(key: "settings-window") {
            SettingsViewModel(
                settingsStore: settingsStore,
                whitelistStore: whitelistStore,
                memoryProvider: memoryProvider,
                onChange: onChange,
                onWhitelistAdded: onWhitelistAdded,
                onWhitelistRemoved: onWhitelistRemoved,
                onExportLogs: onExportLogs
            )
        }

        self.settingsViewModelBinding = settingsViewModelBinding
        self.viewModelSpec = viewModelSpec
        self.viewModel = settingsViewModelBinding.watch(viewModelSpec)

        let defaultContentSize = Self.defaultContentSize()
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentMinSize = defaultContentSize
        window.isReleasedWhenClosed = false
        super.init(window: window)

        window.contentViewController = NSHostingController(
            rootView: SettingsView(viewModelSpec: viewModelSpec)
        )
        updateTitle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        let binding = settingsViewModelBinding
        Task { @MainActor in
            binding.dispose()
        }
    }

    func show() {
        viewModel.load()
        viewModel.refreshMemory()
        updateTitle()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateTitle() {
        window?.title = viewModel.localizer.t("settings.title")
    }

    private static func defaultContentSize() -> NSSize {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1520, height: 960)
        return NSSize(
            width: max(700, visibleFrame.width / 2),
            height: max(580, visibleFrame.height * 2 / 3)
        )
    }
}
