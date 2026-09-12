//
//  AutoStand.swift
//  Desk Controller
//
//  Created by Johan Eklund on 2021-03-05.
//

import Foundation
import CoreGraphics

class AutoStand: NSObject {
    
    private var upTimer: Timer?
    private var downTimer: Timer?
    
    func unschedule() {
        upTimer?.invalidate()
        downTimer?.invalidate()
    }
    
    func update() {
        
        self.unschedule()
        
        if Preferences.shared.automaticStandEnabled {
            // Stand session always end at top of hour
            let now = Date()
            let oneHour:TimeInterval = 3600
            let nextDown = now.nextHour
            var nextUp = Date.init(timeInterval: -Preferences.shared.automaticStandPerHour, since: nextDown)
            
            // Dont schedule in the past
            if nextUp < now {
                nextUp = now + oneHour
            }
            
            upTimer = Timer.init(fire: nextUp, interval: oneHour, repeats: true, block: {_ in
                
                let lastEvent = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: CGEventType(rawValue: ~0)!)

                if  lastEvent < Preferences.shared.automaticStandInactivity {
                    DeskController.shared?.moveToPosition(.stand)
                }
                // print("Fired up timer: \(Date())")
            })
            upTimer?.tolerance = 10
            
            downTimer = Timer.init(fire: nextDown, interval: oneHour, repeats: true, block: {_ in
                // Always return to sitting, even if inactive
                DeskController.shared?.moveToPosition(.sit)
                // print("Fired down timer: \(Date())")
            })
            upTimer?.tolerance = 10
            
            RunLoop.main.add(upTimer!, forMode: .common)
            RunLoop.main.add(downTimer!, forMode: .common)
            // print("Scheduled timers:\n\tUp: \(nextUp)\n\tDown: \(nextDown)")
        }
    }
}
