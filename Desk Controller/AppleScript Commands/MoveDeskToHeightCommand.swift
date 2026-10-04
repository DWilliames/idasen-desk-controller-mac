//
//  MoveDeskToHeightCommand.swift
//  Desk Controller
//
//  Created by David Williames on 3/6/2022.
//

import Foundation

/// `move to "<height>"`.
///
/// Both commands in deskcontroller.sdef declare the Apple event code
/// `lkpstrng`, so Cocoa Scripting hands every `move …` *and* `move to …`
/// event to this class — which used to parse heights only, silently ignoring
/// `move "to-sit"`, `"to-stand"`, `"up"` and `"down"`. Inheriting
/// `MoveDeskCommand`'s handler makes every form work whichever class receives
/// the event, without changing the sdef codes existing compiled scripts use.
class MoveDeskToHeightCommand: MoveDeskCommand {}
