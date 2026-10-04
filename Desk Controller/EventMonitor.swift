//
//  EventMonitor.swift
//  uah
//
//  Created by Maxim on 10/4/15.
//  Copyright © 2015 Maxim Bilan. All rights reserved.
//

import Cocoa

@MainActor
final class EventMonitor {

	private nonisolated(unsafe) var monitor: Any?
	private let mask: NSEvent.EventTypeMask
	private let handler: @Sendable (NSEvent?) -> ()

	init(mask: NSEvent.EventTypeMask, handler: @escaping @Sendable (NSEvent?) -> ()) {
		self.mask = mask
		self.handler = handler
	}

	deinit {
		if let monitor = monitor {
			NSEvent.removeMonitor(monitor)
		}
	}

	func start() {
		monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
	}

	func stop() {
		if let monitor = monitor {
			NSEvent.removeMonitor(monitor)
			self.monitor = nil
		}
	}
}
