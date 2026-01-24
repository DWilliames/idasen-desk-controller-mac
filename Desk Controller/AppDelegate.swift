//
//  AppDelegate.swift
//  Desk Controller
//
//  Created by David Williames on 10/1/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let popover = NSPopover()
    var eventMonitor: EventMonitor?

    var viewController: ViewController?

    private var statusBarMenu: NSMenu?

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        // If it's the first launch set the value for Open at Login to true
        if Preferences.shared.isFirstLaunch {
            Preferences.shared.openAtLogin = true
            Preferences.shared.isFirstLaunch = false
        }

        // Don't show the icon in the Dock
        NSApp.setActivationPolicy(.accessory)

        // Setup the right click menu
        buildStatusBarMenu()

        // Set the status bar icon and action
        if let button = statusBarItem.button {

            if let image = NSImage(named: "StatusBarButtonImage") {
                image.size = NSSize(width: 16, height: 16)
                button.image = image
            }

            button.menu = statusBarMenu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(AppDelegate.clickedStatusItem(_:))
        }

        if let mainViewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "ViewControllerId") as? ViewController {
            mainViewController.popover = popover
            viewController = mainViewController
            popover.contentViewController = mainViewController
        }

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, self.popover.isShown {
                self.closePopover(event)
            }
        }
        eventMonitor?.start()

        // Subscribe to preset changes to rebuild menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(presetsDidChange),
            name: .presetsDidChange,
            object: nil
        )
    }

    @objc func presetsDidChange() {
        buildStatusBarMenu()
    }

    func buildStatusBarMenu() {
        let menu = NSMenu(title: "Desk Controller Menu")

        // Add dynamic preset menu items
        for preset in PresetManager.shared.presets {
            let menuItem = NSMenuItem(
                title: "Move to \(preset.name.lowercased())",
                action: #selector(moveToPreset(_:)),
                keyEquivalent: ""
            )
            menuItem.representedObject = preset.id
            menu.addItem(menuItem)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferences", action: #selector(showPreferences), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "")

        statusBarMenu = menu

        if let button = statusBarItem.button {
            button.menu = menu
        }
    }

    @objc func showPreferences() {
        PreferencesWindowController.sharedInstance.showWindow(nil)
        PreferencesWindowController.sharedInstance.deskController = viewController?.controller
        popover.performClose(self)
    }

    @objc func moveToPreset(_ sender: NSMenuItem) {
        guard let presetId = sender.representedObject as? UUID else { return }
        viewController?.controller?.moveToPosition(.preset(id: presetId))
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {

    }

    @objc func clickedStatusItem(_ sender: NSStatusItem) {
        guard let event = NSApp.currentEvent else {
            return
        }

        if event.type == .rightMouseUp {
            // Right clicked

            // Pop up the menu programmatically
            if let button = statusBarItem.button, let menu = statusBarMenu {
                menu.popUp(positioning: nil, at: CGPoint(x: -15, y: button.bounds.maxY + 6), in: button)
            }


        } else {
            // Left clicked
            togglePopover(sender)
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    func showPopover(_ sender: AnyObject?) {

        guard let button = statusBarItem.button else {
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        eventMonitor?.start()

        // On popover showing; force a reconnection with the Table in case the connection is lost
        viewController?.reconnect()
    }

    func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }

    public static func bringToFront(window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

}
