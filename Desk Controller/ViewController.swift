//
//  ViewController.swift
//  Desk Controller
//
//  Created by David Williames on 10/1/21.
//

import Cocoa
import CoreBluetooth

class ViewController: NSViewController {
    
    var controller: DeskController? = nil
    
    let bluetoothManager = BluetoothManager.shared
    
    @IBOutlet weak var messageLabel: NSTextField?
    @IBOutlet weak var containerStackView: NSStackView?
    
    @IBOutlet weak var currentPositionLabel: NSTextField?
    @IBOutlet weak var currentPositionDimenstionLabel: NSTextField?
    
    @IBOutlet weak var upButton: NSButton?
    @IBOutlet weak var downButton: NSButton?
    
    @IBOutlet weak var sitButton: NSButton?
    @IBOutlet weak var standButton: NSButton?
    
    // Status indicator
    @IBOutlet weak var statusIndicator: NSView?
    @IBOutlet weak var statusLabel: NSTextField?
    @IBOutlet weak var deviceNameLabel: NSTextField?
    
    weak var popover: NSPopover?
    
    
    let stopLabelString = "Stop moving"
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        
        bluetoothManager.onConnectedPeripheralChange = { [weak self] peripheral in
            // print("Connect peripheral updated to: \(String(describing: peripheral))")
            
            DispatchQueue.main.async {
                self?.updateConnectionLabels()
            }
            
            guard let peripheral = peripheral else {
                // print("No peripherals connected – it probably disconnected then")
                return
            }

            self?.setControllerFor(deskPeripheral: peripheral)
        }
        
        bluetoothManager.onCentralManagerStateChange = { [weak self] _ in
            DispatchQueue.main.async {
                self?.controller?.autoStand.unschedule()
                self?.updateConnectionLabels()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        containerStackView?.isHidden = true
        messageLabel?.stringValue = ""
        
        if let indicator = statusIndicator {
            indicator.wantsLayer = true
            indicator.layer?.cornerRadius = indicator.frame.height / 2
        }
        
        statusLabel?.stringValue = "Connecting..."
        deviceNameLabel?.stringValue = ""
        
        currentPositionDimenstionLabel?.stringValue = Preferences.shared.isMetric ? "cm" : "in"
        
        if let position = controller?.desk.position {
            onDeskPositionChange(position)
        }
        
        updateConnectionLabels()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func updateConnectionLabels() {
        
        containerStackView?.isHidden = (bluetoothManager.connectedPeripheral == nil)
        messageLabel?.isHidden = !(bluetoothManager.connectedPeripheral == nil)
        
        statusLabel?.stringValue = (bluetoothManager.connectedPeripheral == nil) ? "Not connected" : "Connected"
        deviceNameLabel?.stringValue = bluetoothManager.connectedPeripheral?.name ?? ""
        statusIndicator?.layer?.backgroundColor = NSColor.red.cgColor
        
        if let centralManager = bluetoothManager.centralManager, let statusLabel = statusLabel {
            
            switch centralManager.state {
            case .poweredOff:
                statusLabel.stringValue = "Turning bluetooth on"
                break
            case .poweredOn:
                statusLabel.stringValue = (bluetoothManager.connectedPeripheral == nil) ? "Not connected" : "Connected"
                messageLabel?.stringValue = "Searching for your Desk... \n\nIf the desk hasn't connected to this Mac before, make sure to set it into pairing mode. \n\nOtherwise, make sure no other apps are currently connected to it."
                
                statusIndicator?.layer?.backgroundColor = (bluetoothManager.connectedPeripheral == nil) ? NSColor.orange.cgColor : NSColor.green.cgColor
                
                if bluetoothManager.connectedPeripheral == nil {
                    deviceNameLabel?.stringValue = "Searching for nearby desks"
                }
                
                break
            case .resetting:
                statusLabel.stringValue = "Reconnecting"
                statusIndicator?.layer?.backgroundColor = NSColor.orange.cgColor
                break
            case .unauthorized:
                statusLabel.stringValue = "Unauthorized"
                break
            case .unknown:
                statusLabel.stringValue = "Unknown status"
                break
            case .unsupported:
                statusLabel.stringValue = "Bluetooth not supported"
                break
            @unknown default:
                break
            }
            
            if centralManager.authorization == .denied {
                statusLabel.stringValue = "Bluetooth access was denied"
                
                messageLabel?.stringValue = "Bluetooth access was denied, but is vital for this application. To re-prompt the permission; delete and re-install this mac application."
            }
        }
    }
    
    func setControllerFor(deskPeripheral: CBPeripheral) {
        // print("Set controller for: \(deskPeripheral)")
        let desk = DeskPeripheral(peripheral: deskPeripheral)
        
        controller = DeskController(desk: desk)
        controller?.onPositionChange({ [weak self] deskPosition in
            DispatchQueue.main.async {
                self?.onDeskPositionChange(deskPosition)
            }
        })
        
        controller?.onCurrentMovingDirectionChange = { [weak self] movingDirection in
            // print("Moving direction changed")
            if movingDirection == .none {
                
                DispatchQueue.main.async {
                    self?.sitButton?.title = "Move to sit"
                    self?.standButton?.title = "Move to stand"
                }
            }
        }
        
    }
    
    func onDeskPositionChange(_ newPosition: Float) {
        DispatchQueue.main.async {
            
            var convertedPosition = newPosition + Preferences.shared.positionOffset
            
            if !Preferences.shared.isMetric {
                convertedPosition = convertedPosition.convertToInches()
            }
            
            self.currentPositionLabel?.stringValue = "\(Int(convertedPosition.rounded()))"

            self.sitButton?.isEnabled = abs((Preferences.shared.sittingPosition - Preferences.shared.positionOffset) - newPosition) > 0.5
            self.standButton?.isEnabled = abs((Preferences.shared.standingPosition - Preferences.shared.positionOffset) - newPosition) > 0.5
        }
    }
    
    func reconnect() {
        // print("Reconnect if necessary")
        
        if bluetoothManager.connectedPeripheral == nil {
            bluetoothManager.startScanning()
        }
        
        if let position = controller?.desk.position {
            onDeskPositionChange(position)
        }
        
    }
    
    @IBAction func moveUpClicked(_ sender: TouchButton) {
        guard let controller = controller else {
            return
        }
        
        if !sender.isPressed {
            controller.stopMoving()
        } else if let position = controller.desk.position, Preferences.shared.standingPosition > position {
            controller.moveToPosition(.stand)
        } else {
            controller.moveUp()
        }
    }
    
    @IBAction func moveDownClicked(_ sender: TouchButton) {
        guard let controller = controller else {
            return
        }
        
        if !sender.isPressed {
            controller.stopMoving()
        } else if let position = controller.desk.position, Preferences.shared.sittingPosition < position {
            controller.moveToPosition(.sit)
        } else {
            controller.moveDown()
        }
    }
    
    @IBAction func sit(_ sender: Any) {
        
        guard let button = sitButton else {
            return
        }
        
        if button.title == stopLabelString {
            controller?.stopMoving()
        } else {
            button.title = stopLabelString
            controller?.moveToPosition(.sit)
        }
    }
    
    @IBAction func stand(_ sender: Any) {
        
        guard let button = standButton else {
            return
        }
        
        if button.title == stopLabelString {
            controller?.stopMoving()
        } else {
            button.title = stopLabelString
            controller?.moveToPosition(.stand)
        }
    }
    
    @IBAction func showPreferences(_ sender: Any) {
        PreferencesWindowController.sharedInstance.showWindow(nil)
        PreferencesWindowController.sharedInstance.deskController = controller
        popover?.performClose(self)
    }
}


