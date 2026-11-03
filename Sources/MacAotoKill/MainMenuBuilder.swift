import AppKit
import MacAotoKillCore

/// 有窗口时显示的菜单栏菜单。也提供 ⌘W、⌘Q 和文本框编辑快捷键。
@MainActor
enum MainMenuBuilder {
    static func makeMenu(localizer: Localizer, target: AppCoordinator) -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(submenuItem(appMenu(localizer: localizer, target: target)))
        mainMenu.addItem(submenuItem(editMenu(localizer: localizer)))
        let windowMenu = windowMenu(localizer: localizer, target: target)
        mainMenu.addItem(submenuItem(windowMenu))
        NSApp.windowsMenu = windowMenu
        return mainMenu
    }

    private static func appMenu(localizer: Localizer, target: AppCoordinator) -> NSMenu {
        let name = AppIdentity.name
        let menu = NSMenu(title: name)
        menu.addItem(item(localizer.t("mainMenu.about", name), #selector(AppCoordinator.showAboutPanel(_:)), target: target))
        menu.addItem(.separator())
        menu.addItem(item(localizer.t("menu.settings"), #selector(AppCoordinator.openSettingsFromMenu(_:)), key: ",", target: target))
        menu.addItem(item(localizer.t("menu.checkForUpdates"), #selector(AppCoordinator.checkForUpdatesFromMenu(_:)), target: target))
        menu.addItem(.separator())
        menu.addItem(item(localizer.t("mainMenu.hide", name), #selector(NSApplication.hide(_:)), key: "h"))
        let hideOthers = item(localizer.t("mainMenu.hideOthers"), #selector(NSApplication.hideOtherApplications(_:)), key: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)
        menu.addItem(item(localizer.t("mainMenu.showAll"), #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item(localizer.t("mainMenu.quit", name), #selector(NSApplication.terminate(_:)), key: "q"))
        return menu
    }

    private static func editMenu(localizer: Localizer) -> NSMenu {
        let menu = NSMenu(title: localizer.t("mainMenu.edit"))
        menu.addItem(item(localizer.t("mainMenu.undo"), Selector(("undo:")), key: "z"))
        let redo = item(localizer.t("mainMenu.redo"), Selector(("redo:")), key: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(.separator())
        menu.addItem(item(localizer.t("mainMenu.cut"), #selector(NSText.cut(_:)), key: "x"))
        menu.addItem(item(localizer.t("mainMenu.copy"), #selector(NSText.copy(_:)), key: "c"))
        menu.addItem(item(localizer.t("mainMenu.paste"), #selector(NSText.paste(_:)), key: "v"))
        menu.addItem(item(localizer.t("mainMenu.selectAll"), #selector(NSText.selectAll(_:)), key: "a"))
        return menu
    }

    private static func windowMenu(localizer: Localizer, target: AppCoordinator) -> NSMenu {
        let menu = NSMenu(title: localizer.t("mainMenu.window"))
        menu.addItem(item(localizer.t("mainMenu.mainWindow"), #selector(AppCoordinator.openMainWindowFromMenu(_:)), key: "0", target: target))
        menu.addItem(.separator())
        menu.addItem(item(localizer.t("mainMenu.minimize"), #selector(NSWindow.performMiniaturize(_:)), key: "m"))
        menu.addItem(item(localizer.t("mainMenu.zoom"), #selector(NSWindow.performZoom(_:))))
        menu.addItem(item(localizer.t("mainMenu.close"), #selector(NSWindow.performClose(_:)), key: "w"))
        return menu
    }

    private static func submenuItem(_ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private static func item(_ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }
}
