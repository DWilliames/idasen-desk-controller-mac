//
//  AppDelegate.swift
//  Desk Controller
//
//  Created by David Williames on 10/1/21.
//

import Cocoa
@preconcurrency import UserNotifications

@main @MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    var eventMonitor: EventMonitor?
    var aboutWindow: AboutWindowController?

    var viewController: ViewController?

    /// Phase the status-bar icon currently reflects, for refresh de-duping.
    /// `nil` until the first render: seeding it with `.disabled` made the
    /// launch-time `applyStatusBarIcon(.disabled)` (auto-stand off) a no-op,
    /// leaving the menu-bar item blank.
    private var lastIconPhase: AutoStand.Phase?

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()

        // If it's the first launch set the value for Open at Login to true
        if Preferences.shared.isFirstLaunch {
            Preferences.shared.openAtLogin = true
            Preferences.shared.isFirstLaunch = false
        }

        // Don't show the icon in the Dock
        NSApp.setActivationPolicy(.accessory)

        // Notifications (used by AutoStand when "notify instead of auto-move" is on).
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.requestAuthorizationIfNeeded()

        // Setup the right click menu
        let statusBarMenu = NSMenu(title: "Desk Controller Menu")
        statusBarMenu.addItem(withTitle: "Move to sit", action: #selector(moveToSit), keyEquivalent: "")
        statusBarMenu.addItem(withTitle: "Move to stand", action: #selector(moveToStand), keyEquivalent: "")
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(withTitle: "Preferences…", action: #selector(showPreferences), keyEquivalent: "")
        statusBarMenu.addItem(withTitle: "About Desk Controller", action: #selector(showAbout), keyEquivalent: "")
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "")

        // Set the status bar icon and action
        if let button = statusBarItem.button {
            // Seed: if auto-stand is enabled but the DeskController (and its
            // AutoStand) hasn't booted yet, show .sitting — the cycle always
            // opens with a sit. AutoStand's first notification will correct
            // this if needed.
            let initialPhase: AutoStand.Phase = Preferences.shared.automaticStandEnabled
                ? (DeskController.shared?.autoStand.currentPhase ?? .sitting)
                : .disabled
            applyStatusBarIcon(phase: initialPhase)
            button.menu = statusBarMenu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(AppDelegate.clickedStatusItem(_:))
        }

        // Observe phase transitions broadcast by AutoStand.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(autoStandPhaseDidChange(_:)),
            name: .autoStandPhaseChanged,
            object: nil
        )
        // After sleep, NSTimer fires may have been suppressed. Pull the
        // current phase out of AutoStand explicitly so the icon doesn't
        // drift stale.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        if let mainViewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "ViewControllerId") as? ViewController {
            mainViewController.popover = popover
            viewController = mainViewController
            popover.contentViewController = mainViewController
        }

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self = self, self.popover.isShown {
                    self.closePopover(nil)
                }
            }
        }
        eventMonitor?.start()
    }

    @objc func showPreferences() {
        PreferencesWindowController.sharedInstance.showWindow(nil)
        PreferencesWindowController.sharedInstance.deskController = viewController?.controller
        popover.performClose(self)
    }

    @objc func moveToSit() {
        viewController?.controller?.moveToPosition(.sit)
    }

    @objc func moveToStand() {
        viewController?.controller?.moveToPosition(.stand)
    }

    // MARK: - Menubar icon

    /// Compatibility shim for the Preferences checkbox path: pulls the current
    /// phase from `AutoStand` (if any) and re-applies the icon. Auto-stand off
    /// always renders the template (disabled) icon regardless of `AutoStand`.
    func refreshAutoStandIcon() {
        let phase: AutoStand.Phase
        if !Preferences.shared.automaticStandEnabled {
            phase = .disabled
        } else {
            phase = DeskController.shared?.autoStand.currentPhase ?? .sitting
        }
        applyStatusBarIcon(phase: phase)
    }

    @objc private func autoStandPhaseDidChange(_ note: Notification) {
        let phase = (note.object as? AutoStand.Phase) ?? .disabled
        applyStatusBarIcon(phase: phase)
    }

    @objc private func systemDidWake() {
        // The phase notification may have been suppressed during sleep. Force
        // a re-read.
        let phase: AutoStand.Phase
        if !Preferences.shared.automaticStandEnabled {
            phase = .disabled
        } else {
            phase = DeskController.shared?.autoStand.currentPhase ?? .sitting
        }
        applyStatusBarIcon(phase: phase)
    }

    private func applyStatusBarIcon(phase: AutoStand.Phase) {
        guard let button = statusBarItem?.button else { return }
        // Skip redundant refreshes, but never while the button has no image.
        guard phase != lastIconPhase || button.image == nil else { return }

        let baseConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let glyphName = "arrow.up.and.down.circle"

        let image: NSImage?
        switch phase {
        case .disabled:
            // Template glyph adopts the menubar foreground colour (light/dark
            // mode aware) when auto-stand is off.
            image = NSImage(systemSymbolName: glyphName,
                            accessibilityDescription: "Desk Controller")?
                .withSymbolConfiguration(baseConfig)
            image?.isTemplate = true
        case .sitting:
            // Sit phase = blue.
            let palette = baseConfig.applying(.init(paletteColors: [.systemBlue]))
            image = NSImage(systemSymbolName: glyphName,
                            accessibilityDescription: "Desk Controller — sitting")?
                .withSymbolConfiguration(palette)
            image?.isTemplate = false
        case .standing:
            // Stand phase = green.
            let palette = baseConfig.applying(.init(paletteColors: [.systemGreen]))
            image = NSImage(systemSymbolName: glyphName,
                            accessibilityDescription: "Desk Controller — standing")?
                .withSymbolConfiguration(palette)
            image?.isTemplate = false
        }

        button.image = image ?? Self.fallbackStatusBarImage()
        button.contentTintColor = nil
        lastIconPhase = phase
    }

    /// The bundled template glyph (the app's original menu-bar icon), used if
    /// the SF Symbol can't be resolved so the status item is never blank.
    private static func fallbackStatusBarImage() -> NSImage? {
        guard let image = NSImage(named: "StatusBarButtonImage")?.copy() as? NSImage else {
            return nil
        }
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return image
    }

    @objc func showAbout() {
        if aboutWindow == nil {
            aboutWindow = AboutWindowController()
        }
        aboutWindow?.showWindow(nil)
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
            if let button = statusBarItem.button, let menu = button.menu {
                menu.popUp(positioning: nil, at: CGPoint(x: -15, y: button.bounds.maxY + 6), in: button)
            }
        } else {
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

extension AppDelegate: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        let actionID = response.actionIdentifier
        Task { @MainActor in
            if NotificationManager.shared.notificationActionWasStand(actionID) {
                DeskController.shared?.moveToPosition(.stand)
            } else if NotificationManager.shared.notificationActionWasSit(actionID) {
                DeskController.shared?.moveToPosition(.sit)
            }
            completionHandler()
        }
    }
}
