import Foundation

@MainActor
struct TemporaryStore {
    let directoryURL: URL
    let storeURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HugoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        storeURL = directoryURL.appendingPathComponent("Hugo.sqlite")
    }

    func remove() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
