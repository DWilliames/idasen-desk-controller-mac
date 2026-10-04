//
//  DebugLog.swift
//  Desk Controller
//
//  Opt-in file-based logger. Off by default. NSLog / os_log output is
//  redacted out of the unified log under hardened-runtime + sandbox on
//  macOS 26, so when something needs deeper debugging this is the escape
//  hatch.
//
//  Enable from a Terminal:
//    defaults write com.davidwilliames.Desk-Controller debugLoggingEnabled -bool true
//
//  Disable:
//    defaults write com.davidwilliames.Desk-Controller debugLoggingEnabled -bool false
//
//  Log file:
//    ~/Library/Containers/com.davidwilliames.Desk-Controller/Data/Library/Application Support/DeskControllerDebug/debug.log
//

import Foundation

enum DebugLog {

    private static let defaultsKey = "debugLoggingEnabled"

    /// Re-read from UserDefaults each access so toggling the flag takes
    /// effect immediately (without needing an app restart). The read is
    /// cheap; we only hit this path for sites that actually call `dbg(_:)`.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    private static let logURL: URL? = {
        let fm = FileManager.default
        let dir: URL
        do {
            dir = try fm.url(for: .applicationSupportDirectory,
                             in: .userDomainMask,
                             appropriateFor: nil,
                             create: true)
        } catch {
            return nil
        }
        let appDir = dir.appendingPathComponent("DeskControllerDebug", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("debug.log")
    }()

    static func write(_ line: String) {
        guard isEnabled, let url = logURL else { return }
        let ts = ISO8601DateFormatter().string(from: Date())
        let entry = "\(ts) \(line)\n"
        guard let data = entry.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: url)
        }
    }
}

/// Call sites use this. No-op (and very cheap) when debug logging isn't enabled.
func dbg(_ message: @autoclosure () -> String) {
    guard DebugLog.isEnabled else { return }
    DebugLog.write(message())
}
