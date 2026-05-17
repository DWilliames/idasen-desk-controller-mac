//
//  ScriptableCommands.swift
//  Desk Controller
//
//  Created by David Williames on 12/1/21.
//

import Foundation

class MoveDeskCommand: NSScriptCommand {
    
    override func performDefaultImplementation() -> Any? {

        guard let parameter = directParameter as? String else {
            return nil
        }
        
        switch parameter {
        case "to-stand":
            DeskController.shared?.moveToPosition(.stand)
            break
        case "to-sit":
            DeskController.shared?.moveToPosition(.sit)
            break
        case "up":
            DeskController.shared?.moveUp()
            break

        case "down":
            DeskController.shared?.moveDown()
            break
        default:
            // Accept absolute-height shortcuts: `move "120cm"`, `move "55in"`,
            // or `move "80"` (cm/in interpreted via the Preferences unit).
            var height: Float?
            if parameter.hasSuffix("cm") {
                height = Float(parameter.dropLast(2))
            } else if parameter.hasSuffix("in") {
                height = Float(parameter.dropLast(2))?.convertToCentimeters()
            } else if let value = Float(parameter) {
                height = Preferences.shared.isMetric ? value : value.convertToCentimeters()
            }
            if let height = height {
                DeskController.shared?.moveToHeight(height)
            }
            break
        }

        return nil
    }
}

