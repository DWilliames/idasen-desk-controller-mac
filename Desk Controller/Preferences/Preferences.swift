//
//  PositionPreferences.swift
//  Desk Controller
//
//  Created by David Williames on 11/1/21.
//

import Foundation
import LaunchAtLogin

enum Position: Sendable {
    case sit, stand, custom(height: Float)
}

@MainActor
class Preferences {

    static let shared = Preferences()

    private let standingKey = "standingPositionValue"
    private let sittingKey = "sittingPositionValue"

    private let automaticStandKey = "automaticStandValue"
    private let automaticStandInactivityKey = "automaticStandInactivityKey"
    private let automaticStandEnabledKey = "automaticStandEnabledKey"

    // New auto-stand model: explicit sit duration + stand duration, instead of
    // "X minutes of standing per clock hour".
    private let standEveryKey = "standEveryMinutes"
    private let standForKey = "standForMinutes"

    private let offsetKey = "positionOffsetValue"

    private let isMetricKey = "isMetric"

    private let hasLaunched = "hasLaunched"

    private let notifyInsteadOfAutoMoveKey = "notifyInsteadOfAutoMove"

    var standingPosition: Float {
        get { UserDefaults.standard.object(forKey: standingKey) as? Float ?? 110 }
        set { UserDefaults.standard.set(newValue, forKey: standingKey) }
    }

    var sittingPosition: Float {
        get { UserDefaults.standard.object(forKey: sittingKey) as? Float ?? 70 }
        set { UserDefaults.standard.set(newValue, forKey: sittingKey) }
    }

    var automaticStandPerHour: TimeInterval {
        get { UserDefaults.standard.object(forKey: automaticStandKey) as? TimeInterval ?? 10 * 60 }
        set {
            UserDefaults.standard.set(newValue, forKey: automaticStandKey)
            DeskController.shared?.autoStand.update()
        }
    }

    /// How long the desk stays SITTING between auto-stands.
    /// Default 50 min. On first launch under the new model it's seeded so
    /// that the old (`standFor + standEvery == 60`) cycle is preserved.
    var standEveryMinutes: Int {
        get {
            if let v = UserDefaults.standard.object(forKey: standEveryKey) as? Int {
                return v
            }
            // Migrate from old `automaticStandPerHour`: assume 60-min cycle.
            let oldStandMin = Int(automaticStandPerHour / 60)
            return max(1, 60 - oldStandMin)
        }
        set {
            UserDefaults.standard.set(max(1, newValue), forKey: standEveryKey)
            DeskController.shared?.autoStand.update()
        }
    }

    /// How long the desk stays STANDING once it goes up. Minimum 5 minutes —
    /// shorter windows aren't enough for the IDÅSEN to physically travel
    /// from sit to stand before the next sit-fire arrives (~40 s of motion
    /// + BT round-trip lag), which caused cycles to silently skip the up.
    var standForMinutes: Int {
        get {
            let stored: Int
            if let v = UserDefaults.standard.object(forKey: standForKey) as? Int {
                stored = v
            } else {
                // Migrate from old `automaticStandPerHour`.
                stored = Int(automaticStandPerHour / 60)
            }
            return max(5, stored)
        }
        set {
            UserDefaults.standard.set(max(5, newValue), forKey: standForKey)
            DeskController.shared?.autoStand.update()
        }
    }

    var automaticStandInactivity: TimeInterval {
        get { UserDefaults.standard.object(forKey: automaticStandInactivityKey) as? TimeInterval ?? 5 * 60 }
        set { UserDefaults.standard.set(newValue, forKey: automaticStandInactivityKey) }
    }

    var automaticStandEnabled: Bool {
        get { UserDefaults.standard.object(forKey: automaticStandEnabledKey) as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: automaticStandEnabledKey)
            DeskController.shared?.autoStand.update()
        }
    }

    var positionOffset: Float {
        get { UserDefaults.standard.object(forKey: offsetKey) as? Float ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: offsetKey) }
    }

    var isMetric: Bool {
        get { UserDefaults.standard.object(forKey: isMetricKey) as? Bool ?? (Locale.current.measurementSystem == .metric) }
        set { UserDefaults.standard.set(newValue, forKey: isMetricKey) }
    }

    var openAtLogin: Bool {
        get { LaunchAtLogin.isEnabled }
        set { LaunchAtLogin.isEnabled = newValue }
    }

    var isFirstLaunch: Bool {
        get { !(UserDefaults.standard.object(forKey: hasLaunched) as? Bool ?? false) }
        set { UserDefaults.standard.set(!newValue, forKey: hasLaunched) }
    }

    /// When `automaticStandEnabled` is on, post a user notification at the scheduled
    /// time instead of physically moving the desk. Off by default for backward compat.
    var notifyInsteadOfAutoMove: Bool {
        get { UserDefaults.standard.object(forKey: notifyInsteadOfAutoMoveKey) as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: notifyInsteadOfAutoMoveKey)
            DeskController.shared?.autoStand.update()
        }
    }

    func forPosition(_ position: Position) -> Float {
        switch position {
        case .sit:
            return sittingPosition - positionOffset
        case .stand:
            return standingPosition - positionOffset
        case .custom(let height):
            return height - positionOffset
        }
    }

    var measurementMetric: Unit {
        return isMetric ? UnitLength.centimeters : UnitLength.inches
    }
}
