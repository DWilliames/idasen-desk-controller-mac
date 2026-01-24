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

    // Stack view to hold dynamically generated preset buttons
    @IBOutlet weak var presetsStackView: NSStackView?

    // Store preset buttons for state management
    private var presetButtons: [UUID: NSButton] = [:]

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

        // Subscribe to preset changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(presetsDidChange),
            name: .presetsDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func presetsDidChange() {
        rebuildPresetButtons()
        if let position = controller?.desk.position {
            updatePresetButtonStates(currentPosition: position)
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

        // Build preset buttons dynamically
        rebuildPresetButtons()

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

    // MARK: - Dynamic Preset Buttons

    func rebuildPresetButtons() {
        guard let stackView = presetsStackView else { return }

        // Remove existing buttons
        for subview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        presetButtons.removeAll()

        // Create buttons for each preset
        for preset in PresetManager.shared.presets {
            let button = NSButton()
            button.title = "Move to \(preset.name.lowercased())"
            button.bezelStyle = .rounded
            button.setButtonType(.momentaryPushIn)
            button.target = self
            button.action = #selector(presetButtonClicked(_:))
            button.translatesAutoresizingMaskIntoConstraints = false

            // Store the preset ID in the button's tag using a mapping
            presetButtons[preset.id] = button

            stackView.addArrangedSubview(button)
        }

        // Set equal widths for all buttons
        if let firstButton = stackView.arrangedSubviews.first {
            for button in stackView.arrangedSubviews.dropFirst() {
                button.widthAnchor.constraint(equalTo: firstButton.widthAnchor).isActive = true
            }
        }
    }

    @objc func presetButtonClicked(_ sender: NSButton) {
        // Find which preset this button belongs to
        guard let presetId = presetButtons.first(where: { $0.value === sender })?.key else { return }
        guard let preset = PresetManager.shared.preset(for: presetId) else { return }

        if sender.title == stopLabelString {
            controller?.stopMoving()
        } else {
            sender.title = stopLabelString
            controller?.moveToPosition(.preset(id: preset.id))
        }
    }

    func updatePresetButtonStates(currentPosition: Float) {
        for preset in PresetManager.shared.presets {
            guard let button = presetButtons[preset.id] else { continue }

            let isAtPosition = preset.heightCm.rounded() == currentPosition.rounded()
            button.isEnabled = !isAtPosition

            // Reset button title if not showing stop
            if button.title == stopLabelString && isAtPosition {
                button.title = "Move to \(preset.name.lowercased())"
            }
        }
    }

    func resetPresetButtonTitles() {
        for preset in PresetManager.shared.presets {
            guard let button = presetButtons[preset.id] else { continue }
            button.title = "Move to \(preset.name.lowercased())"
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
                    self?.resetPresetButtonTitles()
                }
            }
        }

    }

    func onDeskPositionChange(_ newPosition: Float) {
        DispatchQueue.main.async {

            var convertedPosition = newPosition

            if !Preferences.shared.isMetric {
                convertedPosition = convertedPosition.convertToInches()
            }

            self.currentPositionLabel?.stringValue = "\(Int(convertedPosition.rounded()))"

            // Update preset button states
            self.updatePresetButtonStates(currentPosition: newPosition)
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

    @IBAction func showPreferences(_ sender: Any) {
        PreferencesWindowController.sharedInstance.showWindow(nil)
        PreferencesWindowController.sharedInstance.deskController = controller
        popover?.performClose(self)
    }
}
