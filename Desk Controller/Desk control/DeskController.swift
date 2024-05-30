//
//  DeskController.swift
//  Desk Controller
//
//  Created by David Williames on 10/1/21.
//

import Cocoa


enum MovingDirection {
    case up, down, none
}

class DeskController: NSObject {
    
    var onCurrentMovingDirectionChange: (MovingDirection) -> Void = { _ in }
    var currentMovingDirection: MovingDirection = .none {
        didSet {
            // print("Did set current moving direction: \(currentMovingDirection)")
            onCurrentMovingDirectionChange(currentMovingDirection)
        }
    }
    

    var movingToPosition: Position? = nil {
        didSet {
            moveIfNeeded()
        }
    }

    let desk: DeskPeripheral
    
    let autoStand: AutoStand
    
    let distanceOffset: Float = 0.5 // e.g if we're within this of the distance and it's currently moving then we can probably stop
    let minDurationIncrements: TimeInterval = 0.5
    var lastMoveTime: Date
    
    let minMovementIncrements: Float = 0.5 // Make sure it's moved at least 0.75cm before moving again
    var previousMovementIncrement: Float
    
    static var shared: DeskController?
    
    private var positionChangeCallbacks = [(Float) -> Void]()
    
    init(desk: DeskPeripheral) {
        self.desk = desk
        self.lastMoveTime = Date().addingTimeInterval(-minDurationIncrements)
        self.previousMovementIncrement = minMovementIncrements
        self.autoStand = AutoStand()
        super.init()
        
        desk.onPositionChange = { position in
            self.moveIfNeeded()
            self.positionChangeCallbacks.forEach { $0(position) }
        }
        
        DeskController.shared = self
        
        autoStand.update()
        NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(onWakeNote(note:)),
                name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    @objc func onWakeNote(note: NSNotification) {
        BluetoothManager.shared.reconnect()
    }

    
    func onPositionChange(_ callback: @escaping (Float) -> Void) {
        positionChangeCallbacks.append(callback)
    }
    
    
    func moveUp() {
        // print("Move up")
        guard let characteristic = desk.controlCharacteristic else {
            return
        }
        
        if let data = Data(hexString: "4700") {
            desk.peripheral.writeValue(data, for: characteristic, type: .withResponse)
            lastMoveTime = Date()
            currentMovingDirection = .up
        }
    }
    
    func moveDown() {
        // print("Move Down")
        guard let characteristic = desk.controlCharacteristic else {
            return
        }
        
        if let data = Data(hexString: "4600") {
            desk.peripheral.writeValue(data, for: characteristic, type: .withResponse)
            lastMoveTime = Date()
            currentMovingDirection = .down
        }
    }
    
    func stopMoving() {
        guard let characteristic = desk.controlCharacteristic else {
            return
        }
        
        if let data = Data(hexString: "FF00") {
            desk.peripheral.writeValue(data, for: characteristic, type: .withResponse)
            
        }
        
        currentMovingDirection = .none
        movingToPosition = nil
        previousPosition = nil
    }
    
    func moveToPosition(_ position: Position) {
        movingToPosition = position
        // print("Move to position: \(position)")
    }
    
    func moveToHeight(_ height: Float) {
        movingToPosition = .custom(height: height)
    }
    
    
    var previousPosition: Float?
    
    private func moveIfNeeded() {

        guard let toPosition = movingToPosition, var position = desk.position else {
            return
        }
        
        let speed = desk.speed
        position = position + Preferences.shared.positionOffset
        let timeSinceLastMove = lastMoveTime.distance(to: Date())
        let distanceSincePreviousPosition = abs((previousPosition ?? position + minMovementIncrements) - position)
        
        
        let positionToMoveTo = Preferences.shared.forPosition(toPosition)

        
        if positionToMoveTo > position {
            
            if currentMovingDirection == .up {
                position += distanceOffset
            }
            
            if position < positionToMoveTo && speed >= 0 {
                if timeSinceLastMove > minDurationIncrements && distanceSincePreviousPosition >= minMovementIncrements {
                    previousPosition = position
                    moveUp()
                }
                
            } else {
                stopMoving()
            }
        } else if positionToMoveTo < position {
            
            if currentMovingDirection == .down {
                position -= distanceOffset
            }
            
            if position > positionToMoveTo && speed <= 0 {
                if timeSinceLastMove > minDurationIncrements && distanceSincePreviousPosition >= minMovementIncrements {
                    previousPosition = position
                    moveDown()
                }
            } else {
                stopMoving()
            }
        }
        
        
    }
}
