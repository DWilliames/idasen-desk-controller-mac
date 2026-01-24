//
//  DeskPreset.swift
//  Desk Controller
//
//  Data model for a single desk height preset
//

import Foundation

struct DeskPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var heightCm: Float
    var isBuiltIn: Bool
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, heightCm: Float, isBuiltIn: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.heightCm = heightCm
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }

    static func == (lhs: DeskPreset, rhs: DeskPreset) -> Bool {
        return lhs.id == rhs.id
    }
}

// Fixed UUIDs for built-in presets to maintain consistency
extension DeskPreset {
    static let sittingPresetId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let standingPresetId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    static func defaultSittingPreset(height: Float = 70) -> DeskPreset {
        return DeskPreset(
            id: sittingPresetId,
            name: "Sitting",
            heightCm: height,
            isBuiltIn: true,
            sortOrder: 0
        )
    }

    static func defaultStandingPreset(height: Float = 110) -> DeskPreset {
        return DeskPreset(
            id: standingPresetId,
            name: "Standing",
            heightCm: height,
            isBuiltIn: true,
            sortOrder: 1
        )
    }
}
