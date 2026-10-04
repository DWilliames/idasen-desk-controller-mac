//
//  TouchButton.swift
//  Desk Controller
//
//  Created by David Williames on 10/1/21.
//

import Cocoa

class TouchButton: NSButton {
    
    var isPressed = false
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    func setup() {
        sendAction(on: [.leftMouseDown, .leftMouseUp])
    }
    
    override func mouseDown(with event: NSEvent) {
        isPressed = true
        super.mouseDown(with: event)
        isPressed = false
        let _ = target?.perform(action, with: self)
    }
}
