import Foundation
import OSLog

/// Decides whether the SwiftData store lives at the legacy location or in the App Group container.
///
/// The marker file in the group directory is the only authority for "the App Group store is the real store".
/// Files in the group directory without a marker are never trusted.
struct StoreRelocator {
    enum Location: Equatable {
        case legacy
        case appGroup
    }

    struct Resolution: Equatable {
        /// The URL to open.
        var storeURL: URL
        var location: Location
        /// Copied and verified in this launch.
        var isFreshCopy: Bool
        /// The marker said "copied" when the launch started, so the legacy store can be deleted once this launch works.
        var legacyCleanupPending: Bool
    }

    static let storeFileName = "default.store"
    private static let markerFileName = "store-move-state"
    private static let copiedState = "copied"
    private static let confirmedState = "confirmed"
    private static let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Persistence")

    let legacyStoreURL: URL
    private let groupDirectory: URL?
    private let copier: any StoreCopying
    private let fileManager: FileManager

    init(
        legacyStoreURL: URL,
        groupDirectory: URL?,
        copier: any StoreCopying = FileStoreCopier(),
        fileManager: FileManager = .default
    ) {
        self.legacyStoreURL = legacyStoreURL
        self.groupDirectory = groupDirectory
        self.copier = copier
        self.fileManager = fileManager
    }

    private var newStoreURL: URL? {
        groupDirectory?.appending(path: Self.storeFileName)
    }

    private var markerURL: URL? {
        groupDirectory?.appending(path: Self.markerFileName)
    }

    private var legacyResolution: Resolution {
        Resolution(storeURL: legacyStoreURL, location: .legacy, isFreshCopy: false, legacyCleanupPending: false)
    }

    func resolve() -> Resolution {
        guard let groupDirectory, let newStoreURL else { return legacyResolution }
        do {
            try fileManager.createDirectory(at: groupDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error(
                "App Group directory unavailable, using legacy store: \(error.localizedDescription, privacy: .public)")
            return legacyResolution
        }

        if legacyStoreURL.standardizedFileURL.path == newStoreURL.standardizedFileURL.path {
            Self.logger.error("Legacy and App Group store paths are identical, using the single store path")
            return legacyResolution
        }

        let marker = readMarker()
        if marker == Self.confirmedState {
            return appGroupResolution(isFreshCopy: false, legacyCleanupPending: false)
        }
        if marker == Self.copiedState {
            if fileManager.fileExists(atPath: newStoreURL.path) {
                return appGroupResolution(isFreshCopy: false, legacyCleanupPending: true)
            }
            Self.logger.error("Marker says copied but the App Group store is missing, copying again")
            removeMarker()
        }

        guard fileManager.fileExists(atPath: legacyStoreURL.path) else {
            return appGroupResolution(isFreshCopy: false, legacyCleanupPending: false)
        }

        abandonCopy()
        do {
            try copier.copyStore(from: legacyStoreURL, to: newStoreURL)
            try copier.verifyCopy(of: legacyStoreURL, at: newStoreURL)
        } catch {
            Self.logger.error(
                "Copying the store to the App Group failed, using legacy store: \(error.localizedDescription, privacy: .public)"
            )
            abandonCopy()
            return legacyResolution
        }
        return appGroupResolution(isFreshCopy: true, legacyCleanupPending: false)
    }

    /// Writes the marker after the copy has opened and answered a fetch.
    func markCopied() {
        writeMarker(Self.copiedState)
    }

    /// Removes the App Group store files and the marker, so the next launch copies again.
    func abandonCopy() {
        guard let newStoreURL else { return }
        for url in StoreFiles.all(for: newStoreURL) {
            removeIfPresent(url)
        }
        removeMarker()
    }

    /// Deletes the legacy store files and marks the App Group store as confirmed.
    func confirmAndDeleteLegacyStore() {
        for url in StoreFiles.all(for: legacyStoreURL) {
            removeIfPresent(url)
        }
        writeMarker(Self.confirmedState)
    }

    static func productionGroupDirectory(bundle: Bundle = .main, fileManager: FileManager = .default) -> URL? {
        guard
            let identifier = bundle.object(forInfoDictionaryKey: "HugoAppGroupIdentifier") as? String,
            !identifier.isEmpty
        else {
            logger.error("HugoAppGroupIdentifier is missing from Info.plist")
            return nil
        }
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            logger.error("App Group container unavailable for \(identifier, privacy: .public)")
            return nil
        }
        let directory = container.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            logger.error("Could not create App Group store directory: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        return directory
    }

    /// The fixed path of the store in the app's own container, before the App Group move.
    /// Not read from the SwiftData configuration URL, which points into the App Group once the entitlement exists.
    static func productionLegacyStoreURL() -> URL {
        URL.applicationSupportDirectory.appending(path: storeFileName)
    }

    private func appGroupResolution(isFreshCopy: Bool, legacyCleanupPending: Bool) -> Resolution {
        Resolution(
            storeURL: newStoreURL ?? legacyStoreURL,
            location: .appGroup,
            isFreshCopy: isFreshCopy,
            legacyCleanupPending: legacyCleanupPending
        )
    }

    private func readMarker() -> String? {
        guard let markerURL, let text = try? String(contentsOf: markerURL, encoding: .utf8) else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func writeMarker(_ state: String) {
        guard let markerURL else { return }
        do {
            try Data(state.utf8).write(to: markerURL, options: .atomic)
        } catch {
            Self.logger.error("Could not write store move marker: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func removeMarker() {
        guard let markerURL else { return }
        removeIfPresent(markerURL)
    }

    private func removeIfPresent(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            Self.logger.error(
                "Could not remove \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
