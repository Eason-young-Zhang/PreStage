import AppKit
import Foundation

struct CameraVolume: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let hasDCIM: Bool
}

final class VolumeDetectionService {
    private var mountedObserver: NSObjectProtocol?
    private var unmountedObserver: NSObjectProtocol?

    deinit {
        stopMonitoring()
    }

    func detectCameraVolumes() -> [CameraVolume] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []

        return volumes.compactMap { volumeURL in
            guard let values = try? volumeURL.resourceValues(forKeys: Set(keys)) else { return nil }
            let isCameraCandidate = values.volumeIsRemovable == true || values.volumeIsEjectable == true || FileManager.default.fileExists(atPath: volumeURL.appendingPathComponent("DCIM").path)
            guard isCameraCandidate else { return nil }
            let name = values.volumeName ?? volumeURL.lastPathComponent
            let hasDCIM = FileManager.default.fileExists(atPath: volumeURL.appendingPathComponent("DCIM").path)
            return CameraVolume(url: volumeURL, name: name, hasDCIM: hasDCIM)
        }
    }

    func startMonitoring(onChange: @escaping @MainActor () -> Void) {
        stopMonitoring()
        let center = NSWorkspace.shared.notificationCenter
        mountedObserver = center.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in onChange() }
        }
        unmountedObserver = center.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in onChange() }
        }
    }

    func stopMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        if let mountedObserver {
            center.removeObserver(mountedObserver)
        }
        if let unmountedObserver {
            center.removeObserver(unmountedObserver)
        }
        mountedObserver = nil
        unmountedObserver = nil
    }

    func eject(_ volume: CameraVolume, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success: Bool
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
                success = true
            } catch {
                success = false
            }
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
