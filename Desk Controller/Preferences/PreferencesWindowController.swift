//
//  PreferencesWindowController.swift
//  Desk Controller
//
//  Created by David Williames on 11/1/21.
//

import Cocoa

class PreferencesWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet weak var presetsTableView: NSTableView!
    @IBOutlet weak var addPresetButton: NSButton!
    @IBOutlet weak var removePresetButton: NSButton!
    @IBOutlet weak var useCurrentHeightButton: NSButton!

    @IBOutlet weak var unitsPopUpButton: NSPopUpButton!
    @IBOutlet weak var currentHeightField: NSTextField?

    @IBOutlet weak var autoStandEnabledCheckbox: NSButton!
    @IBOutlet weak var autoStandIntervalStepper: NSStepper!
    @IBOutlet weak var autoStandIntervalLabel: NSTextField!
    @IBOutlet weak var autoStandInactiveStepper: NSStepper!
    @IBOutlet weak var autoStandInactiveLabel: NSTextField!

    @IBOutlet weak var openAtLoginCheckbox: NSButton!

    static let sharedInstance = PreferencesWindowController(windowNibName: "PreferencesWindowController")

    var deskController: DeskController? {
        didSet {
            deskPosition = deskController?.desk.position
        }
    }

    var deskPosition: Float? {
        didSet {
            currentHeightField?.isEnabled = (deskPosition != nil)
            useCurrentHeightButton?.isEnabled = (deskPosition != nil && presetsTableView?.selectedRow ?? -1 >= 0)

            var offsetPosition = Preferences.shared.positionOffset + (deskPosition ?? 0)
            if !Preferences.shared.isMetric {
                offsetPosition = offsetPosition.convertToInches()
            }
            currentHeightField?.stringValue = String(format: "%.1f", offsetPosition)
        }
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        openAtLoginCheckbox.state = Preferences.shared.openAtLogin ? .on : .off

        unitsPopUpButton.selectItem(at: Preferences.shared.isMetric ? 0 : 1)

        autoStandEnabledCheckbox.state = Preferences.shared.automaticStandEnabled ? .on : .off
        autoStandIntervalStepper.intValue = Int32(Preferences.shared.automaticStandPerHour / 60)
        autoStandInactiveStepper.intValue = Int32(Preferences.shared.automaticStandInactivity / 60)

        // Setup table view
        presetsTableView?.dataSource = self
        presetsTableView?.delegate = self

        updateLabels()
        updateRemoveButtonState()

        deskController?.onPositionChange({ [weak self] position in
            self?.deskPosition = position
        })

        // Subscribe to preset changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(presetsDidChange),
            name: .presetsDidChange,
            object: nil
        )
    }

    @objc func presetsDidChange() {
        presetsTableView?.reloadData()
        updateRemoveButtonState()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        presetsTableView?.reloadData()
        AppDelegate.bringToFront(window: self.window!)
    }

    func updateLabels() {
        autoStandIntervalLabel.stringValue = String(format: "%.f",
            Preferences.shared.automaticStandPerHour / 60)
        autoStandInactiveLabel.stringValue = String(format: "%.f",
            Preferences.shared.automaticStandInactivity / 60)

        let autoEnabled = Preferences.shared.automaticStandEnabled
        autoStandInactiveLabel.textColor = autoEnabled ? .labelColor : .disabledControlTextColor
        autoStandIntervalLabel.textColor = autoEnabled ? .labelColor : .disabledControlTextColor
        autoStandIntervalStepper.isEnabled = autoEnabled
        autoStandInactiveStepper.isEnabled = autoEnabled

        var offsetPosition = Preferences.shared.positionOffset + (deskPosition ?? 0)
        if !Preferences.shared.isMetric {
            offsetPosition = offsetPosition.convertToInches()
        }

        currentHeightField?.stringValue = String(format: "%.1f", offsetPosition)
    }

    func updateRemoveButtonState() {
        let selectedRow = presetsTableView?.selectedRow ?? -1
        if selectedRow >= 0 && selectedRow < PresetManager.shared.presets.count {
            let preset = PresetManager.shared.presets[selectedRow]
            removePresetButton?.isEnabled = !preset.isBuiltIn
        } else {
            removePresetButton?.isEnabled = false
        }
        useCurrentHeightButton?.isEnabled = (deskPosition != nil && selectedRow >= 0)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return PresetManager.shared.presets.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < PresetManager.shared.presets.count else { return nil }
        let preset = PresetManager.shared.presets[row]

        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")

        if identifier.rawValue == "NameColumn" {
            let cellIdentifier = NSUserInterfaceItemIdentifier("NameCell")
            var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = cellIdentifier
                let textField = NSTextField()
                textField.isBordered = false
                textField.drawsBackground = false
                textField.isEditable = true
                textField.delegate = self
                textField.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(textField)
                cell?.textField = textField
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 2),
                    textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -2),
                    textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                ])
            }

            cell?.textField?.stringValue = preset.name
            cell?.textField?.tag = row
            return cell

        } else if identifier.rawValue == "HeightColumn" {
            let cellIdentifier = NSUserInterfaceItemIdentifier("HeightCell")
            var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = cellIdentifier
                let textField = NSTextField()
                textField.isBordered = false
                textField.drawsBackground = false
                textField.isEditable = true
                textField.delegate = self
                textField.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(textField)
                cell?.textField = textField
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 2),
                    textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -2),
                    textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                ])
            }

            var height = preset.heightCm
            if !Preferences.shared.isMetric {
                height = height.convertToInches()
            }
            cell?.textField?.stringValue = String(format: "%.1f", height)
            cell?.textField?.tag = row + 1000 // Offset to distinguish from name cells
            return cell
        }

        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButtonState()
    }

    // MARK: - Preset Actions

    @IBAction func addPresetClicked(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "New Preset"
        alert.informativeText = "Enter a name for the new preset:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputTextField.stringValue = "New Preset"
        alert.accessoryView = inputTextField

        alert.beginSheetModal(for: self.window!) { [weak self] response in
            if response == .alertFirstButtonReturn {
                let name = inputTextField.stringValue.isEmpty ? "New Preset" : inputTextField.stringValue
                let height = self?.deskPosition ?? 70.0
                PresetManager.shared.addPreset(name: name, heightCm: height + Preferences.shared.positionOffset)
                self?.presetsTableView?.reloadData()
            }
        }
    }

    @IBAction func removePresetClicked(_ sender: Any) {
        let selectedRow = presetsTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < PresetManager.shared.presets.count else { return }

        let preset = PresetManager.shared.presets[selectedRow]
        guard !preset.isBuiltIn else { return }

        let alert = NSAlert()
        alert.messageText = "Delete Preset"
        alert.informativeText = "Are you sure you want to delete \"\(preset.name)\"?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        alert.beginSheetModal(for: self.window!) { response in
            if response == .alertFirstButtonReturn {
                PresetManager.shared.deletePreset(id: preset.id)
            }
        }
    }

    @IBAction func useCurrentHeightClicked(_ sender: Any) {
        let selectedRow = presetsTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < PresetManager.shared.presets.count else { return }
        guard let deskPosition = deskPosition else { return }

        let preset = PresetManager.shared.presets[selectedRow]
        let actualHeight = deskPosition + Preferences.shared.positionOffset
        PresetManager.shared.updatePreset(id: preset.id, heightCm: actualHeight)
        presetsTableView.reloadData()
    }

    @IBAction func changedCurrentHeightField(_ sender: NSTextField) {

        if var newPosition = Float(sender.stringValue), let deskPosition = deskPosition {
            if !Preferences.shared.isMetric {
                newPosition = newPosition.convertToCentimeters()
            }
            let offset = newPosition - deskPosition
            Preferences.shared.positionOffset = offset
        }
    }

    @IBAction func toggledAutoStandCheckbox(_ sender: NSButton) {
        Preferences.shared.automaticStandEnabled = sender.state == .on
        updateLabels()
    }

    @IBAction func changedAutoStandStepper(_ sender: NSStepper) {
        let newInterval = Double(autoStandIntervalStepper.intValue)
        Preferences.shared.automaticStandPerHour = newInterval * 60
        updateLabels()
    }

    @IBAction func changedAutoStandInactiveStepper(_ sender: NSStepper) {
        let newInactive = Double(autoStandInactiveStepper.intValue)
        Preferences.shared.automaticStandInactivity = newInactive * 60
        updateLabels()
    }

    @IBAction func changedUnitsPopUpButton(_ sender: NSPopUpButton) {
        Preferences.shared.isMetric = sender.titleOfSelectedItem == "cm"
        presetsTableView?.reloadData()
        updateLabels()
    }

    @IBAction func toggledOpenAtLoginCheckbox(_ sender: NSButton) {
        Preferences.shared.openAtLogin = sender.state == .on
    }
}

// MARK: - NSTextFieldDelegate for inline editing

extension PreferencesWindowController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let tag = textField.tag

        if tag < 1000 {
            // Name column
            let row = tag
            guard row >= 0 && row < PresetManager.shared.presets.count else { return }
            let preset = PresetManager.shared.presets[row]
            let newName = textField.stringValue.isEmpty ? preset.name : textField.stringValue
            PresetManager.shared.updatePreset(id: preset.id, name: newName)
        } else {
            // Height column
            let row = tag - 1000
            guard row >= 0 && row < PresetManager.shared.presets.count else { return }
            guard var newHeight = Float(textField.stringValue) else { return }

            if !Preferences.shared.isMetric {
                newHeight = newHeight.convertToCentimeters()
            }

            let preset = PresetManager.shared.presets[row]
            PresetManager.shared.updatePreset(id: preset.id, heightCm: newHeight)
        }
    }
}
