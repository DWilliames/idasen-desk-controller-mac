//
//  PositionPreferences.swift
//  Desk Controller
//
//  Created by David Williames on 11/1/21.
//

import Foundation
import LaunchAtLogin

enum Position {
    case sit, stand, preset(id: UUID), custom(height: Float)
}

class Preferences {

    static let shared = Preferences()

    private let standingKey = "standingPositionValue"
    private let sittingKey = "sittingPositionValue"

    private let automaticStandKey = "automaticStandValue"
    private let automaticStandInactivityKey = "automaticStandInactivityKey"
    private let automaticStandEnabledKey = "automaticStandEnabledKey"

    private let offsetKey = "positionOffsetValue"

    private let isMetricKey = "isMetric"

    private let hasLaunched = "hasLaunched"

    var standingPosition: Float {
        get {
            // Route through PresetManager for consistency
            if let preset = PresetManager.shared.standingPreset {
                return preset.heightCm
            }
            // Fallback to legacy value
            if let position = UserDefaults.standard.value(forKey: standingKey) {
                return position as! Float
            }
            return 110 // Default standing position
        }

        set {
            // Update PresetManager
            PresetManager.shared.updatePreset(id: DeskPreset.standingPresetId, heightCm: newValue)
            // Also save to legacy key for backward compatibility
            UserDefaults.standard.setValue(newValue, forKey: standingKey)
        }
    }

    var sittingPosition: Float {
        get {
            // Route through PresetManager for consistency
            if let preset = PresetManager.shared.sittingPreset {
                return preset.heightCm
            }
            // Fallback to legacy value
            if let position = UserDefaults.standard.value(forKey: sittingKey) {
                return position as! Float
            }
            return 70 // Default sitting position
        }

        set {
            // Update PresetManager
            PresetManager.shared.updatePreset(id: DeskPreset.sittingPresetId, heightCm: newValue)
            // Also save to legacy key for backward compatibility
            UserDefaults.standard.setValue(newValue, forKey: sittingKey)
        }
    }

    var automaticStandPerHour: TimeInterval {
        get {
            if let standTime = UserDefaults.standard.value(forKey: automaticStandKey) {
                return standTime as! TimeInterval
            }
            return 10 * 60 // Default automatic stand
        }

        set {
            //print("Save new Automatic stand per hour: \(newValue)")
            UserDefaults.standard.setValue(newValue, forKey: automaticStandKey)
            DeskController.shared?.autoStand.update()
        }
    }

    var automaticStandInactivity: TimeInterval {
        get {
            if let inactiveTime = UserDefaults.standard.value(forKey: automaticStandInactivityKey) {
                return inactiveTime as! TimeInterval
            }
            return 5 * 60 // Default min
        }

        set {
            //print("Save new Automatic stand inactivity: \(newValue)")
            UserDefaults.standard.setValue(newValue, forKey: automaticStandInactivityKey)
        }
    }

    var automaticStandEnabled: Bool {
        get {
            if let autoStandEnabled = UserDefaults.standard.value(forKey: automaticStandEnabledKey) {
                return autoStandEnabled as! Bool
            }
            return false // Default disabled
        }

        set {
            //print("Saving automatic stand enabled \(newValue)")
            UserDefaults.standard.setValue(newValue, forKey: automaticStandEnabledKey)
            // Stop timers
            DeskController.shared?.autoStand.update()
        }
    }

    var positionOffset: Float {
        get {
            if let offset = UserDefaults.standard.value(forKey: offsetKey) {
                return offset as! Float
            }
            return 0 // Default offset
        }

        set {
            // print("Save new position Offset: \(newValue)")
            UserDefaults.standard.setValue(newValue, forKey: offsetKey)
        }
    }

    var isMetric: Bool {
        get {
            if let metric = UserDefaults.standard.value(forKey: isMetricKey) {
                return metric as! Bool
            }
            return NSLocale.current.usesMetricSystem // Default from locale
        }

        set {
            // print("Saving is metric? \(newValue)")
            UserDefaults.standard.setValue(newValue, forKey: isMetricKey)
        }
    }

    var openAtLogin: Bool {
        get {
            return LaunchAtLogin.isEnabled
        }
        set {
            // print("Saving launch at login: \(newValue)")
            LaunchAtLogin.isEnabled = newValue
        }
    }

    var isFirstLaunch: Bool {
        get {
            if let hasLaunchedBefore = UserDefaults.standard.value(forKey: hasLaunched) {
                return !(hasLaunchedBefore as! Bool)
            }
            return true
        }

        set {
            UserDefaults.standard.setValue(!newValue, forKey: hasLaunched)
        }
    }

    func forPosition(_ position: Position) -> Float {
        switch position {
        case .sit:
            return sittingPosition
        case .stand:
            return standingPosition
        case .preset(let id):
            if let preset = PresetManager.shared.preset(for: id) {
                return preset.heightCm
            }
            return sittingPosition // Fallback to sitting position if preset not found
        case .custom(let height):
            return height
        }
    }

    var measurementMetric: Unit {
        return isMetric ? UnitLength.centimeters : UnitLength.inches
    }
}
