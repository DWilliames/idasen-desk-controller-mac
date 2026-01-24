//
//  PresetManager.swift
//  Desk Controller
//
//  Storage and CRUD operations for desk height presets
//

import Foundation

extension Notification.Name {
    static let presetsDidChange = Notification.Name("presetsDidChange")
}

class PresetManager {

    static let shared = PresetManager()

    private let presetsKey = "deskPresets"
    private let hasMigratedKey = "hasMigratedPresets"

    // Legacy keys for migration
    private let legacySittingKey = "sittingPositionValue"
    private let legacyStandingKey = "standingPositionValue"

    private(set) var presets: [DeskPreset] = []

    private init() {
        loadPresets()
        migrateIfNeeded()
    }

    private func notifyPresetsChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .presetsDidChange, object: nil)
        }
    }

    // MARK: - CRUD Operations

    func addPreset(name: String, heightCm: Float) {
        let maxSortOrder = presets.map { $0.sortOrder }.max() ?? -1
        let newPreset = DeskPreset(
            name: name,
            heightCm: heightCm,
            isBuiltIn: false,
            sortOrder: maxSortOrder + 1
        )
        presets.append(newPreset)
        savePresets()
        notifyPresetsChanged()
    }

    func updatePreset(id: UUID, name: String? = nil, heightCm: Float? = nil) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }

        if let name = name {
            presets[index].name = name
        }
        if let heightCm = heightCm {
            presets[index].heightCm = heightCm
        }
        savePresets()
        notifyPresetsChanged()
    }

    func deletePreset(id: UUID) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        // Prevent deletion of built-in presets
        guard !presets[index].isBuiltIn else { return }

        presets.remove(at: index)
        savePresets()
        notifyPresetsChanged()
    }

    func preset(for id: UUID) -> DeskPreset? {
        return presets.first(where: { $0.id == id })
    }

    func reorderPresets(_ newOrder: [DeskPreset]) {
        for (index, preset) in newOrder.enumerated() {
            if let existingIndex = presets.firstIndex(where: { $0.id == preset.id }) {
                presets[existingIndex].sortOrder = index
            }
        }
        presets.sort { $0.sortOrder < $1.sortOrder }
        savePresets()
        notifyPresetsChanged()
    }

    // MARK: - Convenience accessors for built-in presets

    var sittingPreset: DeskPreset? {
        return presets.first(where: { $0.id == DeskPreset.sittingPresetId })
    }

    var standingPreset: DeskPreset? {
        return presets.first(where: { $0.id == DeskPreset.standingPresetId })
    }

    // MARK: - Persistence

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: presetsKey),
              let savedPresets = try? JSONDecoder().decode([DeskPreset].self, from: data) else {
            // Initialize with default presets
            presets = [
                DeskPreset.defaultSittingPreset(),
                DeskPreset.defaultStandingPreset()
            ]
            savePresets()
            return
        }
        presets = savedPresets.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: presetsKey)
    }

    // MARK: - Migration from legacy settings

    private func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: hasMigratedKey) else { return }

        // Check for legacy sitting position
        if let legacySitting = UserDefaults.standard.value(forKey: legacySittingKey) as? Float {
            updatePreset(id: DeskPreset.sittingPresetId, heightCm: legacySitting)
        }

        // Check for legacy standing position
        if let legacyStanding = UserDefaults.standard.value(forKey: legacyStandingKey) as? Float {
            updatePreset(id: DeskPreset.standingPresetId, heightCm: legacyStanding)
        }

        UserDefaults.standard.set(true, forKey: hasMigratedKey)
    }
}
