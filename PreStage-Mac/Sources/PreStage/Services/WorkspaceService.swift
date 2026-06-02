import Foundation

final class WorkspaceService {
    private let defaults: UserDefaults
    private let key = "PreStage.workspace.default"
    private let libraryKey = "PreStage.workspace.library"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> WorkspacePreset {
        let library = loadLibrary()
        return library.presets.first { $0.id == library.activePresetID } ?? library.presets.first ?? .default
    }

    func save(_ preset: WorkspacePreset) {
        var library = loadLibrary()
        if let index = library.presets.firstIndex(where: { $0.id == preset.id }) {
            library.presets[index] = preset
        } else {
            library.presets.append(preset)
        }
        library.activePresetID = preset.id
        saveLibrary(library)
        saveLegacyDefault(preset)
    }

    func loadLibrary() -> WorkspaceLibrary {
        if let data = defaults.data(forKey: libraryKey),
           let library = try? JSONDecoder().decode(WorkspaceLibrary.self, from: data),
           !library.presets.isEmpty {
            return library
        }

        guard let data = defaults.data(forKey: key),
              let preset = try? JSONDecoder().decode(WorkspacePreset.self, from: data) else {
            return .default
        }
        let library = WorkspaceLibrary(activePresetID: preset.id, presets: [preset])
        saveLibrary(library)
        return library
    }

    func saveLibrary(_ library: WorkspaceLibrary) {
        guard let data = try? JSONEncoder().encode(library) else { return }
        defaults.set(data, forKey: libraryKey)
        if let active = library.presets.first(where: { $0.id == library.activePresetID }) {
            saveLegacyDefault(active)
        }
    }

    private func saveLegacyDefault(_ preset: WorkspacePreset) {
        guard let data = try? JSONEncoder().encode(preset) else { return }
        defaults.set(data, forKey: key)
    }
}
