//
//  AboutWindowController.swift
//  Desk Controller
//
//  A minimal, Rectangle-style About window: app icon, name, version + build,
//  copyright. Pulls everything from the bundle's Info.plist so it stays in
//  sync with whatever CI builds.
//

import Cocoa

@MainActor
final class AboutWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
        buildUI()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        AppDelegate.bringToFront(window: self.window!)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let info = Bundle.main.infoDictionary ?? [:]
        let appName = (info["CFBundleName"] as? String) ?? "Desk Controller"
        let version = (info["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (info["CFBundleVersion"] as? String) ?? "?"
        let bundleID = Bundle.main.bundleIdentifier ?? ""

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSApp.applicationIconImage ?? NSImage(named: "AppIcon")
        iconView.imageScaling = .scaleProportionallyUpOrDown

        let nameLabel = NSTextField(labelWithString: appName)
        nameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        nameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: "Version \(version) (\(build))")
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let copyrightLabel = NSTextField(wrappingLabelWithString: copyrightText())
        copyrightLabel.alignment = .center
        copyrightLabel.font = .systemFont(ofSize: 11)
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.maximumNumberOfLines = 3

        let repoButton = NSButton(title: "GitHub", target: self, action: #selector(openRepo))
        repoButton.bezelStyle = .accessoryBarAction
        repoButton.controlSize = .small

        // Detect the repository URL from the bundle ID prefix so the About window
        // doesn't hard-code the marcobazzani fork.
        let repoURL: String = {
            if bundleID.contains("davidwilliames") {
                return "https://github.com/DWilliames/idasen-desk-controller-mac"
            }
            return "https://github.com/marcobazzani/idasen-desk-controller-mac"
        }()
        repoButton.toolTip = repoURL
        repoButton.identifier = NSUserInterfaceItemIdentifier(repoURL)

        let stack = NSStackView(views: [iconView, nameLabel, versionLabel, copyrightLabel, repoButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(14, after: iconView)
        stack.setCustomSpacing(4, after: nameLabel)
        stack.setCustomSpacing(18, after: versionLabel)

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 96),
            iconView.heightAnchor.constraint(equalToConstant: 96),
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 36),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24)
        ])
    }

    private func copyrightText() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        if let copyright = info["NSHumanReadableCopyright"] as? String, !copyright.isEmpty {
            return copyright
        }
        let year = Calendar.current.component(.year, from: Date())
        return "Copyright © 2021–\(year) David Williames and contributors.\nAll rights reserved."
    }

    @objc private func openRepo(_ sender: NSButton) {
        guard let url = sender.identifier.flatMap({ URL(string: $0.rawValue) }) else { return }
        NSWorkspace.shared.open(url)
    }
}
