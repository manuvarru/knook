import Foundation

enum AppStorageLocations {
    static let currentSupportDirectoryName = "knook-ita"
    static let legacySupportDirectoryNames = ["knook", "nook", "Nook"]

    static var applicationSupportBaseURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    static func currentFileURL(named fileName: String) -> URL {
        applicationSupportBaseURL
            .appendingPathComponent(currentSupportDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func legacyFileURLs(named fileName: String) -> [URL] {
        legacySupportDirectoryNames.map { directoryName in
            applicationSupportBaseURL
                .appendingPathComponent(directoryName, isDirectory: true)
                .appendingPathComponent(fileName, isDirectory: false)
        }
    }
}
