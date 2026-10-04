//
//  PreferencesWindowController.swift
//  Desk Controller
//
//  Created by David Williames on 11/1/21.
//

import Cocoa

class PreferencesWindowController: NSWindowController {
    
    @IBOutlet weak var standingHeightField: NSTextField!
    @IBOutlet weak var sittingHeightField: NSTextField!
    
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
            // Always (re-)register the position observer with the *current*
            // DeskController. The controller is rebuilt on every BT
            // reconnect, so a one-time hookup in windowDidLoad would point
            // at a stale instance after a reconnect.
            deskController?.onPositionChange({ [weak self] position in
                self?.deskPosition = position
            })
        }
    }

    var deskPosition: Float? {
        didSet {
            currentHeightField?.isEnabled = (deskPosition != nil)

            var offsetPosition = Preferences.shared.positionOffset + (deskPosition ?? 0)
            if !Preferences.shared.isMetric {
                offsetPosition = offsetPosition.convertToInches()
            }
            currentHeightField?.stringValue = String(format: "%.1f", offsetPosition)

            // Move the marker on the position bar to track the desk.
            schedulePreview?.currentPosition = deskPosition
        }
    }
    
    private var notifyInsteadCheckbox: NSButton?
    private var schedulePreview: SchedulePreviewView?
    private var standForStepper: NSStepper?
    private var standForValueLabel: NSTextField?
    private var standForRowLabel: NSTextField?

    override func windowDidLoad() {
        super.windowDidLoad()

        openAtLoginCheckbox.state = Preferences.shared.openAtLogin ? .on : .off

        unitsPopUpButton.selectItem(at: Preferences.shared.isMetric ? 0 : 1)

        autoStandEnabledCheckbox.state = Preferences.shared.automaticStandEnabled ? .on : .off
        // Repurposed: existing "Automatically stand" stepper now means
        // "Stand every X minutes" (was "X minutes per hour").
        autoStandIntervalStepper.intValue = Int32(Preferences.shared.standEveryMinutes)
        autoStandInactiveStepper.intValue = Int32(Preferences.shared.automaticStandInactivity / 60)

        addExtraControls()

        updateLabels()

        // The first-load registration is a no-op when deskController is set
        // via the property setter (didSet handles re-registration there);
        // this covers the legacy code path where deskController existed
        // before the property setter fired.
        deskController?.onPositionChange({ [weak self] position in
            self?.deskPosition = position
        })
    }

    /// Programmatically rebuild the autostand block (three rows: Stand every,
    /// Stand for, Activity timeout) plus add the notify toggle and green
    /// schedule preview bar. Hides the XIB autostand controls so the
    /// programmatic stack owns that region.
    private func addExtraControls() {
        guard let content = window?.contentView else { return }

        // 1) Hide every XIB element that belongs to the autostand block —
        //    checkbox, two existing steppers, value labels, the "Activity
        //    timeout:" static label, and the original explainer text. We
        //    replace them with a single programmatic stack.
        autoStandEnabledCheckbox.isHidden = true
        autoStandIntervalStepper.isHidden = true
        autoStandIntervalLabel.isHidden = true
        autoStandInactiveStepper.isHidden = true
        autoStandInactiveLabel.isHidden = true
        let titlesToHide: Set<String> = [
            "Activity timeout:",
            "Automatically raise the desk the specified number of minutes per hour if the computer is active.",
            "The desk sits for the first interval, then stands for the second, then repeats — as long as you've been active recently."
        ]
        for sub in content.subviews {
            if let tf = sub as? NSTextField, titlesToHide.contains(tf.stringValue) {
                tf.isHidden = true
            }
        }

        // 2) Build the new programmatic stack: three rows + explainer.
        let masterCheckbox = NSButton(checkboxWithTitle: "Automatically stand",
                                      target: self, action: #selector(masterAutoStandToggled(_:)))
        masterCheckbox.state = Preferences.shared.automaticStandEnabled ? .on : .off
        masterAutoStandCheckbox = masterCheckbox

        let standEveryRow = makeMinutesRow(label: "Stand every:",
                                            value: Preferences.shared.standEveryMinutes,
                                            min: 1, max: 240,
                                            action: #selector(standEveryStepperChanged(_:)),
                                            stepperOut: &programmaticStandEveryStepper,
                                            labelOut: &programmaticStandEveryLabel)
        let standForRow = makeMinutesRow(label: "Stand for:",
                                         value: Preferences.shared.standForMinutes,
                                         min: 5, max: 60,
                                         action: #selector(standForStepperChanged(_:)),
                                         stepperOut: &programmaticStandForStepper,
                                         labelOut: &programmaticStandForLabel)
        let timeoutRow = makeMinutesRow(label: "Activity timeout:",
                                        value: Int(Preferences.shared.automaticStandInactivity / 60),
                                        min: 1, max: 60,
                                        action: #selector(activityTimeoutStepperChanged(_:)),
                                        stepperOut: &programmaticActivityStepper,
                                        labelOut: &programmaticActivityLabel)

        let explainer = NSTextField(wrappingLabelWithString:
            "Sit for the first interval, then stand for the second, then repeat. Skipped if you've been idle longer than the activity timeout.")
        explainer.font = .systemFont(ofSize: 10)
        explainer.textColor = .tertiaryLabelColor
        explainer.maximumNumberOfLines = 0
        explainer.preferredMaxLayoutWidth = 220

        // The XIB "Open Desk Controller at login" stays hidden — we own its
        // replacement programmatically so we control its position.
        openAtLoginCheckbox.isHidden = true
        let loginCheckbox = NSButton(checkboxWithTitle: "Open Desk Controller at login",
                                     target: self, action: #selector(toggledOpenAtLoginInline(_:)))
        loginCheckbox.state = Preferences.shared.openAtLogin ? .on : .off
        loginCheckbox.translatesAutoresizingMaskIntoConstraints = false

        // Autostand block — master toggle, the three rows, and the explainer
        // text. NO "Open at login" inside this block; it lives separately at
        // the bottom of the window.
        let block = NSStackView(views: [
            masterCheckbox,
            standEveryRow,
            standForRow,
            timeoutRow,
            explainer
        ])
        block.orientation = .vertical
        block.alignment = .leading
        block.spacing = 6
        block.translatesAutoresizingMaskIntoConstraints = false

        // Notify checkbox + preview bar + login checkbox live at the bottom,
        // pinned to the content-view bottom.
        let notifyToggle = NSButton(checkboxWithTitle: "Notify instead of moving the desk",
                                    target: self, action: #selector(toggledNotifyInstead))
        notifyToggle.state = Preferences.shared.notifyInsteadOfAutoMove ? .on : .off
        notifyToggle.translatesAutoresizingMaskIntoConstraints = false
        notifyToggle.lineBreakMode = .byWordWrapping
        notifyToggle.cell?.wraps = true
        notifyToggle.cell?.isScrollable = false
        notifyInsteadCheckbox = notifyToggle

        let preview = SchedulePreviewView(frame: .zero)
        preview.translatesAutoresizingMaskIntoConstraints = false
        schedulePreview = preview

        content.addSubview(block)
        content.addSubview(preview)
        content.addSubview(loginCheckbox)
        content.addSubview(notifyToggle)

        // Bottom stack (top→bottom): preview bar, Open at login, Notify.
        NSLayoutConstraint.activate([
            block.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            block.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),
            block.topAnchor.constraint(equalTo: content.topAnchor, constant: 230),
            block.bottomAnchor.constraint(lessThanOrEqualTo: preview.topAnchor, constant: -12),

            preview.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            preview.bottomAnchor.constraint(equalTo: loginCheckbox.topAnchor, constant: -10),
            preview.widthAnchor.constraint(equalToConstant: 180),
            preview.heightAnchor.constraint(equalToConstant: 8),

            loginCheckbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            loginCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),
            loginCheckbox.bottomAnchor.constraint(equalTo: notifyToggle.topAnchor, constant: -6),

            notifyToggle.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            notifyToggle.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),
            notifyToggle.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)
        ])

        if let win = window {
            var frame = win.frame
            let extra: CGFloat = 28 /* notify */ + 8 /* preview */ + 60 /* extra row */ + 24 /* gaps */
            frame.origin.y -= extra
            frame.size.height += extra
            win.setFrame(frame, display: false)
        }
    }

    // MARK: programmatic-stack helpers

    private var masterAutoStandCheckbox: NSButton?
    private var programmaticStandEveryStepper: NSStepper?
    private var programmaticStandEveryLabel: NSTextField?
    private var programmaticStandForStepper: NSStepper?
    private var programmaticStandForLabel: NSTextField?
    private var programmaticActivityStepper: NSStepper?
    private var programmaticActivityLabel: NSTextField?

    private func makeMinutesRow(label: String, value: Int, min: Double, max: Double,
                                 action: Selector,
                                 stepperOut: inout NSStepper?,
                                 labelOut: inout NSTextField?) -> NSView {
        // Right-align titles in a 120 pt column so the value sits at the same
        // x as the XIB rows above (Standing height / Sitting height / etc.).
        let title = NSTextField(labelWithString: label)
        title.alignment = .right
        title.translatesAutoresizingMaskIntoConstraints = false
        title.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let valueLabel = NSTextField(labelWithString: String(value))
        valueLabel.alignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true
        labelOut = valueLabel

        let stepper = NSStepper()
        stepper.minValue = min
        stepper.maxValue = max
        stepper.increment = 1
        stepper.intValue = Int32(value)
        stepper.autorepeat = true           // hold-to-spin
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = action
        stepperOut = stepper

        let unit = NSTextField(labelWithString: "min")
        unit.textColor = .secondaryLabelColor

        let row = NSStackView(views: [title, valueLabel, stepper, unit])
        row.orientation = .horizontal
        row.spacing = 4
        return row
    }

    @objc private func masterAutoStandToggled(_ sender: NSButton) {
        Preferences.shared.automaticStandEnabled = sender.state == .on
        updateLabels()
        (NSApp.delegate as? AppDelegate)?.refreshAutoStandIcon()
    }

    @objc private func standEveryStepperChanged(_ sender: NSStepper) {
        Preferences.shared.standEveryMinutes = Int(sender.intValue)
        updateLabels()
    }

    @objc private func standForStepperChanged(_ sender: NSStepper) {
        Preferences.shared.standForMinutes = Int(sender.intValue)
        updateLabels()
    }

    @objc private func activityTimeoutStepperChanged(_ sender: NSStepper) {
        Preferences.shared.automaticStandInactivity = Double(sender.intValue) * 60
        updateLabels()
    }

    @objc private func toggledOpenAtLoginInline(_ sender: NSButton) {
        Preferences.shared.openAtLogin = sender.state == .on
    }

    private func refreshSchedulePreview() {
        // Bar now visualises the desk's physical height between sit and
        // stand presets. Gray left half = sit region, green right half =
        // stand region, vertical marker = current desk height.
        let sit = Preferences.shared.sittingPosition
        let stand = Preferences.shared.standingPosition
        let enabled = Preferences.shared.automaticStandEnabled
        schedulePreview?.sittingPosition = sit
        schedulePreview?.standingPosition = stand
        schedulePreview?.currentPosition = deskPosition
        // Bar stays visible even when auto-stand is off — it's a passive
        // position indicator, not an auto-stand-only widget.
        schedulePreview?.enabled = enabled
        schedulePreview?.isHidden = false

        let standForMins = Preferences.shared.standForMinutes
        let standEveryMins = Preferences.shared.standEveryMinutes
        if enabled {
            schedulePreview?.toolTip = "Sit \(standEveryMins) min · Stand \(standForMins) min · repeat"
        } else {
            schedulePreview?.toolTip = "Sit / Stand range. Auto-stand is off."
        }
    }

    @objc private func toggledNotifyInstead(_ sender: NSButton) {
        Preferences.shared.notifyInsteadOfAutoMove = sender.state == .on
        if sender.state == .on {
            NotificationManager.shared.requestAuthorizationIfNeeded()
        }
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        AppDelegate.bringToFront(window: self.window!)
    }
    
    func updateLabels() {
        
        var standingPosition = Preferences.shared.standingPosition
        var sittingPosition = Preferences.shared.sittingPosition
        
        if !Preferences.shared.isMetric {
            standingPosition = standingPosition.convertToInches()
            sittingPosition = sittingPosition.convertToInches()
        }
        
        standingHeightField.stringValue = String(format: "%.1f", standingPosition)
        sittingHeightField.stringValue = String(format: "%.1f", sittingPosition)
        
        // Programmatic autostand controls
        let autoEnabled = Preferences.shared.automaticStandEnabled
        masterAutoStandCheckbox?.state = autoEnabled ? .on : .off
        programmaticStandEveryLabel?.stringValue = String(Preferences.shared.standEveryMinutes)
        programmaticStandEveryStepper?.intValue = Int32(Preferences.shared.standEveryMinutes)
        programmaticStandForLabel?.stringValue = String(Preferences.shared.standForMinutes)
        programmaticStandForStepper?.intValue = Int32(Preferences.shared.standForMinutes)
        let timeoutMin = Int(Preferences.shared.automaticStandInactivity / 60)
        programmaticActivityLabel?.stringValue = String(timeoutMin)
        programmaticActivityStepper?.intValue = Int32(timeoutMin)
        programmaticStandEveryStepper?.isEnabled = autoEnabled
        programmaticStandForStepper?.isEnabled = autoEnabled
        programmaticActivityStepper?.isEnabled = autoEnabled
        let stateColor: NSColor = autoEnabled ? .labelColor : .disabledControlTextColor
        programmaticStandEveryLabel?.textColor = stateColor
        programmaticStandForLabel?.textColor = stateColor
        programmaticActivityLabel?.textColor = stateColor
        
        var offsetPosition = Preferences.shared.positionOffset + (deskPosition ?? 0)
        if !Preferences.shared.isMetric {
            offsetPosition = offsetPosition.convertToInches()
        }

        currentHeightField?.stringValue = String(format: "%.1f", offsetPosition)

        refreshSchedulePreview()
    }
    
    @IBAction func changeStandingHeightField(_ sender: NSTextField) {
        
        if var newPosition = Float(standingHeightField.stringValue) {
            if !Preferences.shared.isMetric {
                newPosition = newPosition.convertToCentimeters()
            }
            Preferences.shared.standingPosition = newPosition
        }
        
    }
    
    @IBAction func changedSittingHeightField(_ sender: NSTextField) {
        
        if var newPosition = Float(sittingHeightField.stringValue) {
            if !Preferences.shared.isMetric {
                newPosition = newPosition.convertToCentimeters()
            }
            Preferences.shared.sittingPosition = newPosition
        }
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
        (NSApp.delegate as? AppDelegate)?.refreshAutoStandIcon()
    }
    
    @objc private func changedStandForStepper(_ sender: NSStepper) {
        Preferences.shared.standForMinutes = Int(sender.intValue)
        updateLabels()
    }

    @IBAction func changedAutoStandStepper(_ sender: NSStepper) {
        Preferences.shared.standEveryMinutes = Int(autoStandIntervalStepper.intValue)
        updateLabels()
    }
    
    @IBAction func changedAutoStandInactiveStepper(_ sender: NSStepper) {
        let newInactive = Double(autoStandInactiveStepper.intValue)
        Preferences.shared.automaticStandInactivity = newInactive * 60
        updateLabels()
    }
    
    @IBAction func changedUnitsPopUpButton(_ sender: NSPopUpButton) {
        Preferences.shared.isMetric = sender.titleOfSelectedItem == "cm"
        updateLabels()
    }
    
    @IBAction func toggledOpenAtLoginCheckbox(_ sender: NSButton) {
        Preferences.shared.openAtLogin = sender.state == .on
    }


}


// MARK: - Desk position bar

/// Visual indicator of the desk's *physical* position between the sit and
/// stand presets. The bar's left edge = `sittingPosition`, right edge =
/// `standingPosition`. Left half is gray (sit region), right half is green
/// (stand region), split at the midpoint. A vertical marker shows where the
/// desk currently sits within that range.
final class SchedulePreviewView: NSView {

    /// Lower-bound cm (the sit preset).
    var sittingPosition: Float = 70 {
        didSet { if oldValue != sittingPosition { needsDisplay = true } }
    }
    /// Upper-bound cm (the stand preset).
    var standingPosition: Float = 110 {
        didSet { if oldValue != standingPosition { needsDisplay = true } }
    }
    /// Current desk height in cm, or `nil` if not connected yet.
    var currentPosition: Float? {
        didSet { if oldValue != currentPosition { needsDisplay = true } }
    }
    var enabled: Bool = true {
        didSet { if oldValue != enabled { needsDisplay = true } }
    }

    override var wantsDefaultClipping: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let radius: CGFloat = rect.height / 2

        let sit = sittingPosition
        let stand = standingPosition
        guard stand > sit else {
            // Degenerate: presets misconfigured. Just draw an empty track.
            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return
        }

        // Left half (gray = sit region).
        let trackFill: NSColor = enabled ? .quaternaryLabelColor : .quaternaryLabelColor.withAlphaComponent(0.5)
        trackFill.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

        // Right half (green = stand region) clipped to rounded outline.
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
        let standFill: NSColor = enabled
            ? .systemGreen
            : NSColor.systemGreen.withAlphaComponent(0.4)
        standFill.setFill()
        let rightHalf = NSRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height)
        rightHalf.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        // Current-position marker.
        if let current = currentPosition {
            let clamped = max(sit, min(stand, current))
            let t = CGFloat((clamped - sit) / (stand - sit))   // 0…1
            let x = rect.minX + rect.width * t
            let markerWidth: CGFloat = 2
            let markerRect = NSRect(x: x - markerWidth / 2,
                                    y: rect.minY - 2,
                                    width: markerWidth,
                                    height: rect.height + 4)
            let markerColor: NSColor = enabled ? .labelColor : .labelColor.withAlphaComponent(0.5)
            markerColor.setFill()
            markerRect.fill()
        }

        // Outer border.
        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        border.lineWidth = 1
        border.stroke()
    }
}

