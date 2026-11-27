import CryptoKit
import Foundation

/// Copies a SwiftData SQLite store, with its companions, to another location.
protocol StoreCopying {
    /// Copies the store file, its `-wal` and `-shm` files and its support directory. Missing companions are skipped.
    func copyStore(from source: URL, to destination: URL) throws

    /// Throws unless every file that exists at `source` exists at `destination` with the same size and SHA-256.
    func verifyCopy(of source: URL, at destination: URL) throws
}

/// The files that make up one SwiftData store, all in the store's directory.
enum StoreFiles {
    /// The main store file, `<store>-wal`, `<store>-shm` and `.<name>_SUPPORT`.
    static func all(for storeURL: URL) -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let name = storeURL.lastPathComponent
        let stem = storeURL.deletingPathExtension().lastPathComponent
        return [
            storeURL,
            directory.appending(path: "\(name)-wal"),
            directory.appending(path: "\(name)-shm"),
            directory.appending(path: ".\(stem)_SUPPORT"),
        ]
    }
}

struct FileStoreCopier: StoreCopying {
    private static let chunkSize = 1_024 * 1_024

    func copyStore(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        for (sourceFile, destinationFile) in pairs(from: source, to: destination) {
            guard fileManager.fileExists(atPath: sourceFile.path) else { continue }
            try fileManager.copyItem(at: sourceFile, to: destinationFile)
        }
    }

    func verifyCopy(of source: URL, at destination: URL) throws {
        let fileManager = FileManager.default
        for (sourceFile, destinationFile) in pairs(from: source, to: destination) {
            guard fileManager.fileExists(atPath: sourceFile.path) else { continue }
            for (sourceRegular, destinationRegular) in try regularFilePairs(sourceFile, destinationFile) {
                guard fileManager.fileExists(atPath: destinationRegular.path) else {
                    throw CocoaError(.fileNoSuchFile)
                }
                let sourceSize = try fileSize(sourceRegular)
                let destinationSize = try fileSize(destinationRegular)
                guard sourceSize == destinationSize else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                guard try sha256(of: sourceRegular) == sha256(of: destinationRegular) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
            }
        }
    }

    private func pairs(from source: URL, to destination: URL) -> [(URL, URL)] {
        let sourceFiles = StoreFiles.all(for: source)
        let destinationFiles = StoreFiles.all(for: destination)
        return zip(sourceFiles, destinationFiles).map { ($0, $1) }
    }

    /// Expands a directory into its regular files. A plain file maps to itself.
    private func regularFilePairs(_ source: URL, _ destination: URL) throws -> [(URL, URL)] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            return []
        }
        guard isDirectory.boolValue else {
            return [(source, destination)]
        }
        let sourceRoot = source.standardizedFileURL.path
        let enumerator = FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey])
        var result: [(URL, URL)] = []
        while let item = enumerator?.nextObject() as? URL {
            let values = try item.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let relative = String(item.standardizedFileURL.path.dropFirst(sourceRoot.count))
            result.append((item, destination.appending(path: relative)))
        }
        return result
    }

    private func fileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? -1
    }

    private func sha256(of url: URL) throws -> SHA256.Digest {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: Self.chunkSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize()
    }
}
